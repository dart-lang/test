// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:multi_server_socket/multi_server_socket.dart';
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:pub_semver/pub_semver.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:yaml/yaml.dart';

import '../../backend/runtime.dart';
import '../../backend/suite_platform.dart';
import '../../util/io.dart';
import '../../util/stack_trace_mapper.dart';
import '../../utils.dart';
import '../application_exception.dart';
import '../compiler_pool.dart';
import '../configuration.dart';
import '../configuration/suite.dart';
import '../executable_settings.dart';
import '../load_exception.dart';
import '../plugin/customizable_platform.dart';
import '../plugin/environment.dart';
import '../plugin/platform.dart';
import '../plugin/platform_helpers.dart';
import '../runner_suite.dart';

/// The first Dart SDK version where `--categories=Server` disables `dart:html`
/// rather than disabling all JS-specific libraries.
final _firstServerSdk = new Version.parse("2.0.0-dev.42.0");

/// A platform that loads tests in Node.js processes.
class NodePlatform extends PlatformPlugin
    implements CustomizablePlatform<ExecutableSettings> {
  /// The test runner configuration.
  final Configuration _config;

  /// The [CompilerPool] managing active instances of `dart2js`.
  final _compilers = () {
    var arguments = ["-Dnode=true"];
    if (sdkVersion >= _firstServerSdk) arguments.add("--categories=Server");
    return new CompilerPool(arguments);
  }();

  /// The temporary directory in which compiled JS is emitted.
  final _compiledDir = createTempDir();

  /// The HTTP client to use when fetching JS files for `pub serve`.
  final HttpClient _http;

  /// Executable settings for [Runtime.nodeJS] and runtimes that extend
  /// it.
  final _settings = {
    Runtime.nodeJS: new ExecutableSettings(
        linuxExecutable: "node",
        macOSExecutable: "node",
        windowsExecutable: "node.exe")
  };

  NodePlatform()
      : _config = Configuration.current,
        _http =
            Configuration.current.pubServeUrl == null ? null : new HttpClient();

  ExecutableSettings parsePlatformSettings(YamlMap settings) =>
      new ExecutableSettings.parse(settings);

  ExecutableSettings mergePlatformSettings(
          ExecutableSettings settings1, ExecutableSettings settings2) =>
      settings1.merge(settings2);

  void customizePlatform(Runtime runtime, ExecutableSettings settings) {
    var oldSettings = _settings[runtime] ?? _settings[runtime.root];
    if (oldSettings != null) settings = oldSettings.merge(settings);
    _settings[runtime] = settings;
  }

  StreamChannel loadChannel(String path, SuitePlatform platform) =>
      throw new UnimplementedError();

  Future<RunnerSuite> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Object message) async {
    var pair = await _loadChannel(path, platform.runtime, suiteConfig);
    var controller = deserializeSuite(path, platform, suiteConfig,
        new PluginEnvironment(), pair.first, message);

    controller.channel("test.node.mapper").sink.add(pair.last?.serialize());

    return await controller.suite;
  }

  /// Loads a [StreamChannel] communicating with the test suite at [path].
  ///
  /// Returns that channel along with a [StackTraceMapper] representing the
  /// source map for the compiled suite.
  Future<Pair<StreamChannel, StackTraceMapper>> _loadChannel(
      String path, Runtime runtime, SuiteConfiguration suiteConfig) async {
    var server = await MultiServerSocket.loopback(0);

    try {
      var pair = await _spawnProcess(path, runtime, suiteConfig, server.port);
      var process = pair.first;

      // Forward Node's standard IO to the print handler so it's associated with
      // the load test.
      //
      // TODO(nweiz): Associate this with the current test being run, if any.
      process.stdout.transform(lineSplitter).listen(print);
      process.stderr.transform(lineSplitter).listen(print);

      var socket = await server.first;
      // TODO(nweiz): Remove the DelegatingStreamSink wrapper when sdk#31504 is
      // fixed.
      var channel = new StreamChannel(socket, new DelegatingStreamSink(socket))
          .transform(new StreamChannelTransformer.fromCodec(utf8))
          .transform(chunksToLines)
          .transform(jsonDocument)
          .transformStream(
              new StreamTransformer.fromHandlers(handleDone: (sink) {
        if (process != null) process.kill();
        sink.close();
      }));

      return new Pair(channel, pair.last);
    } catch (_) {
      server.close().catchError((_) {});
      rethrow;
    }
  }

  /// Spawns a Node.js process that loads the Dart test suite at [path].
  ///
  /// Returns that channel along with a [StackTraceMapper] representing the
  /// source map for the compiled suite.
  Future<Pair<Process, StackTraceMapper>> _spawnProcess(String path,
      Runtime runtime, SuiteConfiguration suiteConfig, int socketPort) async {
    if (_config.suiteDefaults.precompiledPath != null) {
      return _spawnPrecompiledProcess(path, runtime, suiteConfig, socketPort,
          _config.suiteDefaults.precompiledPath);
    } else if (_config.pubServeUrl != null) {
      return _spawnPubServeProcess(path, runtime, suiteConfig, socketPort);
    } else {
      return _spawnNormalProcess(path, runtime, suiteConfig, socketPort);
    }
  }

  /// Compiles [testPath] with dart2js, adds the node preamble, and then spawns
  /// a Node.js process that loads that Dart test suite.
  Future<Pair<Process, StackTraceMapper>> _spawnNormalProcess(String testPath,
      Runtime runtime, SuiteConfiguration suiteConfig, int socketPort) async {
    var dir = new Directory(_compiledDir).createTempSync('test_').path;
    var jsPath = p.join(dir, p.basename(testPath) + ".node_test.dart.js");
    await _compilers.compile('''
        import "package:test/src/bootstrap/node.dart";

        import "${p.toUri(p.absolute(testPath))}" as test;

        void main() {
          internalBootstrapNodeTest(() => test.main);
        }
      ''', jsPath, suiteConfig);

    // Add the Node.js preamble to ensure that the dart2js output is
    // compatible. Use the minified version so the source map remains valid.
    var jsFile = new File(jsPath);
    await jsFile.writeAsString(
        preamble.getPreamble(minified: true) + await jsFile.readAsString());

    StackTraceMapper mapper;
    if (!suiteConfig.jsTrace) {
      var mapPath = jsPath + '.map';
      mapper = new StackTraceMapper(await new File(mapPath).readAsString(),
          mapUrl: p.toUri(mapPath),
          packageResolver: await PackageResolver.current.asSync,
          sdkRoot: p.toUri(sdkDir));
    }

    return new Pair(await _startProcess(runtime, jsPath, socketPort), mapper);
  }

  /// Spawns a Node.js process that loads the Dart test suite at [testPath]
  /// under [precompiledPath].
  Future<Pair<Process, StackTraceMapper>> _spawnPrecompiledProcess(
      String testPath,
      Runtime runtime,
      SuiteConfiguration suiteConfig,
      int socketPort,
      String precompiledPath) async {
    StackTraceMapper mapper;
    var jsPath = p.join(precompiledPath, '$testPath.node_test.dart.js');
    if (!suiteConfig.jsTrace) {
      var mapPath = jsPath + '.map';
      var resolver = await SyncPackageResolver
          .loadConfig(p.toUri(p.join(precompiledPath, '.packages')));
      mapper = new StackTraceMapper(await new File(mapPath).readAsString(),
          mapUrl: p.toUri(mapPath),
          packageResolver: resolver,
          sdkRoot: p.toUri(sdkDir));
    }

    return new Pair(await _startProcess(runtime, jsPath, socketPort), mapper);
  }

  /// Requests the compiled js for [testPath] from the pub serve url, prepends
  /// the node preamble, and then spawns a Node.js process that loads that Dart
  /// test suite.
  Future<Pair<Process, StackTraceMapper>> _spawnPubServeProcess(String testPath,
      Runtime runtime, SuiteConfiguration suiteConfig, int socketPort) async {
    var dir = new Directory(_compiledDir).createTempSync('test_').path;
    var jsPath = p.join(dir, p.basename(testPath) + ".node_test.dart.js");
    var url = _config.pubServeUrl.resolveUri(
        p.toUri(p.relative(testPath, from: 'test') + '.node_test.dart.js'));

    var js = await _get(url, testPath);
    await new File(jsPath)
        .writeAsString(preamble.getPreamble(minified: true) + js);

    StackTraceMapper mapper;
    if (!suiteConfig.jsTrace) {
      var mapUrl = url.replace(path: url.path + '.map');
      mapper = new StackTraceMapper(await _get(mapUrl, testPath),
          mapUrl: mapUrl,
          packageResolver: new SyncPackageResolver.root('packages'),
          sdkRoot: p.toUri('packages/\$sdk'));
    }

    return new Pair(await _startProcess(runtime, jsPath, socketPort), mapper);
  }

  /// Starts the Node.js process for [runtime] with [jsPath].
  Future<Process> _startProcess(
      Runtime runtime, String jsPath, int socketPort) async {
    var settings = _settings[runtime];

    var nodeModules = p.absolute('node_modules');
    var nodePath = Platform.environment["NODE_PATH"];
    nodePath = nodePath == null ? nodeModules : "$nodePath:$nodeModules";

    try {
      return await Process.start(settings.executable,
          settings.arguments.toList()..add(jsPath)..add(socketPort.toString()),
          environment: {'NODE_PATH': nodePath});
    } catch (error, stackTrace) {
      await new Future.error(
          new ApplicationException(
              "Failed to run ${runtime.name}: ${getErrorMessage(error)}"),
          stackTrace);
      return null;
    }
  }

  /// Runs an HTTP GET on [url].
  ///
  /// If this fails, throws a [LoadException] for [suitePath].
  Future<String> _get(Uri url, String suitePath) async {
    try {
      var response = await (await _http.getUrl(url)).close();

      if (response.statusCode != 200) {
        // We don't care about the response body, but we have to drain it or
        // else the process can't exit.
        response.listen(null);

        throw new LoadException(
            suitePath,
            "Error getting $url: ${response.statusCode} "
            "${response.reasonPhrase}\n"
            'Make sure "pub serve" is serving the test/ directory.');
      }

      return await utf8.decodeStream(response);
    } on IOException catch (error) {
      var message = getErrorMessage(error);
      if (error is SocketException) {
        message = "${error.osError.message} "
            "(errno ${error.osError.errorCode})";
      }

      throw new LoadException(
          suitePath,
          "Error getting $url: $message\n"
          'Make sure "pub serve" is running.');
    }
  }

  Future close() => _closeMemo.runOnce(() async {
        await _compilers.close();

        if (_config.pubServeUrl == null) {
          new Directory(_compiledDir).deleteSync(recursive: true);
        } else {
          _http.close();
        }
      });
  final _closeMemo = new AsyncMemoizer();
}
