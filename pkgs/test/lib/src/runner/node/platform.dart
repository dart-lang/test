// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:test_api/backend.dart'
    show Compiler, Runtime, StackTraceMapper, SuitePlatform;
import 'package:test_core/src/runner/application_exception.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/dart2js_compiler_pool.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/load_exception.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/package_version.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/customizable_platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/environment.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/platform_helpers.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/runner_suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/wasm_compiler_pool.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/errors.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/package_config.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports
import 'package:yaml/yaml.dart';

import '../../util/package_map.dart';
import '../executable_settings.dart';

/// A platform that loads tests in Node.js processes.
class NodePlatform extends PlatformPlugin
    implements CustomizablePlatform<ExecutableSettings> {
  /// The test runner configuration.
  final Configuration _config;

  /// The [Dart2JsCompilerPool] managing active instances of `dart2js`.
  final _jsCompilers = Dart2JsCompilerPool(['-Dnode=true', '--server-mode']);
  final _wasmCompilers = WasmCompilerPool(['-Dnode=true']);

  /// The temporary directory in which compiled JS is emitted.
  final _compiledDir = createTempDir();

  /// Executable settings for [Runtime.nodeJS] and runtimes that extend
  /// it.
  final _settings = {
    Runtime.nodeJS: ExecutableSettings(
        linuxExecutable: 'node',
        macOSExecutable: 'node',
        windowsExecutable: 'node.exe')
  };

  NodePlatform() : _config = Configuration.current;

  @override
  ExecutableSettings parsePlatformSettings(YamlMap settings) =>
      ExecutableSettings.parse(settings);

  @override
  ExecutableSettings mergePlatformSettings(
          ExecutableSettings settings1, ExecutableSettings settings2) =>
      settings1.merge(settings2);

  @override
  void customizePlatform(Runtime runtime, ExecutableSettings settings) {
    var oldSettings = _settings[runtime] ?? _settings[runtime.root];
    if (oldSettings != null) settings = oldSettings.merge(settings);
    _settings[runtime] = settings;
  }

  @override
  Future<RunnerSuite> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Map<String, Object?> message) async {
    if (platform.compiler != Compiler.dart2js &&
        platform.compiler != Compiler.dart2wasm) {
      throw StateError(
          'Unsupported compiler for the Node platform ${platform.compiler}.');
    }
    var (channel, stackMapper) =
        await _loadChannel(path, platform, suiteConfig);
    var controller = deserializeSuite(path, platform, suiteConfig,
        const PluginEnvironment(), channel, message);

    controller.channel('test.node.mapper').sink.add(stackMapper?.serialize());

    return await controller.suite;
  }

  /// Loads a [StreamChannel] communicating with the test suite at [path].
  ///
  /// Returns that channel along with a [StackTraceMapper] representing the
  /// source map for the compiled suite.
  Future<(StreamChannel<Object?>, StackTraceMapper?)> _loadChannel(String path,
      SuitePlatform platform, SuiteConfiguration suiteConfig) async {
    final servers = await _loopback();

    try {
      var (process, stackMapper) =
          await _spawnProcess(path, platform, suiteConfig, servers.first.port);

      // Forward Node's standard IO to the print handler so it's associated with
      // the load test.
      //
      // TODO(nweiz): Associate this with the current test being run, if any.
      process.stdout.transform(lineSplitter).listen(print);
      process.stderr.transform(lineSplitter).listen(print);

      // Wait for the first connection (either over ipv4 or v6). If the proccess
      // exits before it connects, throw instead of waiting for a connection
      // indefinitely.
      var socket = await Future.any([
        StreamGroup.merge(servers).first,
        process.exitCode.then((_) => null),
      ]);

      if (socket == null) {
        throw LoadException(
            path, 'Node exited before connecting to the test channel.');
      }

      var channel = StreamChannel(socket.cast<List<int>>(), socket)
          .transform(StreamChannelTransformer.fromCodec(utf8))
          .transform(_chunksToLines)
          .transform(jsonDocument)
          .transformStream(StreamTransformer.fromHandlers(handleDone: (sink) {
        process.kill();
        sink.close();
      }));

      return (channel, stackMapper);
    } finally {
      unawaited(Future.wait<void>(servers.map((s) =>
          s.close().then<ServerSocket?>((v) => v).onError((_, __) => null))));
    }
  }

  /// Spawns a Node.js process that loads the Dart test suite at [path].
  ///
  /// Returns that channel along with a [StackTraceMapper] representing the
  /// source map for the compiled suite.
  Future<(Process, StackTraceMapper?)> _spawnProcess(
      String path,
      SuitePlatform platform,
      SuiteConfiguration suiteConfig,
      int socketPort) async {
    if (_config.suiteDefaults.precompiledPath != null) {
      return _spawnPrecompiledProcess(path, platform.runtime, suiteConfig,
          socketPort, _config.suiteDefaults.precompiledPath!);
    } else {
      return switch (platform.compiler) {
        Compiler.dart2js => _spawnNormalJsProcess(
            path, platform.runtime, suiteConfig, socketPort),
        Compiler.dart2wasm => _spawnNormalWasmProcess(
            path, platform.runtime, suiteConfig, socketPort),
        _ => throw StateError('Unsupported compiler ${platform.compiler}'),
      };
    }
  }

  Future<String> _entrypointScriptForTest(
      String testPath, SuiteConfiguration suiteConfig) async {
    return '''
        ${suiteConfig.metadata.languageVersionComment ?? await rootPackageLanguageVersionComment}
        import "package:test/src/bootstrap/node.dart";

        import "${p.toUri(p.absolute(testPath))}" as test;

        void main() {
          internalBootstrapNodeTest(() => test.main);
        }
      ''';
  }

  /// Compiles [testPath] with dart2js, adds the node preamble, and then spawns
  /// a Node.js process that loads that Dart test suite.
  Future<(Process, StackTraceMapper?)> _spawnNormalJsProcess(String testPath,
      Runtime runtime, SuiteConfiguration suiteConfig, int socketPort) async {
    var dir = Directory(_compiledDir).createTempSync('test_').path;
    var jsPath = p.join(dir, '${p.basename(testPath)}.node_test.dart.js');
    await _jsCompilers.compile(
      await _entrypointScriptForTest(testPath, suiteConfig),
      jsPath,
      suiteConfig,
    );

    // Add the Node.js preamble to ensure that the dart2js output is
    // compatible. Use the minified version so the source map remains valid.
    var jsFile = File(jsPath);
    await jsFile.writeAsString(
        preamble.getPreamble(minified: true) + await jsFile.readAsString());

    StackTraceMapper? mapper;
    if (!suiteConfig.jsTrace) {
      var mapPath = '$jsPath.map';
      mapper = JSStackTraceMapper(await File(mapPath).readAsString(),
          mapUrl: p.toUri(mapPath),
          sdkRoot: Uri.parse('org-dartlang-sdk:///sdk'),
          packageMap: (await currentPackageConfig).toPackageMap());
    }

    return (await _startProcess(runtime, jsPath, socketPort), mapper);
  }

  /// Compiles [testPath] with dart2wasm, adds a JS entrypoint and then spawns
  /// a Node.js process loading the compiled test suite.
  Future<(Process, StackTraceMapper?)> _spawnNormalWasmProcess(String testPath,
      Runtime runtime, SuiteConfiguration suiteConfig, int socketPort) async {
    var dir = Directory(_compiledDir).createTempSync('test_').path;
    // dart2wasm will emit a .wasm file and a .mjs file responsible for loading
    // that file.
    var wasmPath = p.join(dir, '${p.basename(testPath)}.node_test.dart.wasm');
    var loader = '${p.basename(testPath)}.node_test.dart.wasm.mjs';

    // We need to create an additional entrypoint file loading the wasm module.
    var jsPath = p.join(dir, '${p.basename(testPath)}.node_test.dart.js');

    await _wasmCompilers.compile(
      await _entrypointScriptForTest(testPath, suiteConfig),
      wasmPath,
      suiteConfig,
    );

    await File(jsPath).writeAsString('''
const { createReadStream } = require('fs');
const { once } = require('events');
const { PassThrough } = require('stream');

const main = async () => {
  const { instantiate, invoke } = await import("./$loader");

  const wasmContents = createReadStream("$wasmPath.wasm");
  const stream = new PassThrough();
  wasmContents.pipe(stream);

  await once(wasmContents, 'open');
  const response = new Response(
    stream,
    {
      headers: {
        "Content-Type": "application/wasm"
      }
    }
  );
  const instancePromise = WebAssembly.compileStreaming(response);
  const module = await instantiate(instancePromise, {});
  invoke(module);
};

main();
''');

    return (await _startProcess(runtime, jsPath, socketPort), null);
  }

  /// Spawns a Node.js process that loads the Dart test suite at [testPath]
  /// under [precompiledPath].
  Future<(Process, StackTraceMapper?)> _spawnPrecompiledProcess(
      String testPath,
      Runtime runtime,
      SuiteConfiguration suiteConfig,
      int socketPort,
      String precompiledPath) async {
    StackTraceMapper? mapper;
    var jsPath = p.join(precompiledPath, '$testPath.node_test.dart.js');
    if (!suiteConfig.jsTrace) {
      var mapPath = '$jsPath.map';
      mapper = JSStackTraceMapper(await File(mapPath).readAsString(),
          mapUrl: p.toUri(mapPath),
          sdkRoot: Uri.parse('org-dartlang-sdk:///sdk'),
          packageMap: (await findPackageConfig(Directory(precompiledPath)))!
              .toPackageMap());
    }

    return (await _startProcess(runtime, jsPath, socketPort), mapper);
  }

  /// Starts the Node.js process for [runtime] with [jsPath].
  Future<Process> _startProcess(
      Runtime runtime, String jsPath, int socketPort) async {
    var settings = _settings[runtime]!;

    var nodeModules = p.absolute('node_modules');
    var nodePath = Platform.environment['NODE_PATH'];
    nodePath = nodePath == null ? nodeModules : '$nodePath:$nodeModules';

    try {
      return await Process.start(
          settings.executable,
          settings.arguments.toList()
            ..add(jsPath)
            ..add(socketPort.toString()),
          environment: {'NODE_PATH': nodePath});
    } catch (error, stackTrace) {
      await Future<Never>.error(
          ApplicationException(
              'Failed to run ${runtime.name}: ${getErrorMessage(error)}'),
          stackTrace);
    }
  }

  @override
  Future<void> close() => _closeMemo.runOnce(() async {
        await _jsCompilers.close();
        await _wasmCompilers.close();
        await Directory(_compiledDir).deleteWithRetry();
      });
  final _closeMemo = AsyncMemoizer<void>();
}

Future<List<ServerSocket>> _loopback({int remainingRetries = 5}) async {
  if (!await _supportsIPv4) {
    return [await ServerSocket.bind(InternetAddress.loopbackIPv6, 0)];
  }

  var v4Server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  if (!await _supportsIPv6) return [v4Server];

  try {
    // Reuse the IPv4 server's port so that if [port] is 0, both servers use
    // the same ephemeral port.
    var v6Server =
        await ServerSocket.bind(InternetAddress.loopbackIPv6, v4Server.port);
    return [v4Server, v6Server];
  } on SocketException catch (error) {
    if (error.osError?.errorCode != _addressInUseErrno) rethrow;
    if (remainingRetries == 0) rethrow;

    // A port being available on IPv4 doesn't necessarily mean that the same
    // port is available on IPv6. If it's not (which is rare in practice),
    // we try again until we find one that's available on both.
    unawaited(v4Server.close());
    return await _loopback(remainingRetries: remainingRetries - 1);
  }
}

/// Whether this computer supports binding to IPv6 addresses.
final Future<bool> _supportsIPv6 = () async {
  try {
    var socket = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    unawaited(socket.close());
    return true;
  } on SocketException catch (_) {
    return false;
  }
}();

/// Whether this computer supports binding to IPv4 addresses.
final Future<bool> _supportsIPv4 = () async {
  try {
    var socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(socket.close());
    return true;
  } on SocketException catch (_) {
    return false;
  }
}();

/// The error code for an error caused by a port already being in use.
final int _addressInUseErrno = () {
  if (Platform.isWindows) return 10048;
  if (Platform.isMacOS) return 48;
  assert(Platform.isLinux);
  return 98;
}();

/// A [StreamChannelTransformer] that converts a chunked string channel to a
/// line-by-line channel.
///
/// Note that this is only safe for channels whose messages are guaranteed not
/// to contain newlines.
final _chunksToLines = StreamChannelTransformer<String, String>(
    const LineSplitter(),
    StreamSinkTransformer.fromHandlers(
        handleData: (data, sink) => sink.add('$data\n')));
