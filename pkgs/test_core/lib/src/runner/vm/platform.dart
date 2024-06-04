// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test_api/backend.dart';
import 'package:vm_service/vm_service.dart' hide Isolate;
import 'package:vm_service/vm_service_io.dart';

import '../../runner/configuration.dart';
import '../../runner/environment.dart';
import '../../runner/load_exception.dart';
import '../../runner/platform.dart';
import '../../runner/plugin/platform_helpers.dart';
import '../../runner/plugin/shared_platform_helpers.dart';
import '../../runner/runner_suite.dart';
import '../../runner/suite.dart';
import '../../util/io.dart';
import '../../util/package_config.dart';
import '../package_version.dart';
import 'environment.dart';
import 'test_compiler.dart';

var _shouldPauseAfterTests = false;

/// A platform that loads tests in isolates spawned within this Dart process.
class VMPlatform extends PlatformPlugin {
  /// The test runner configuration.
  final _config = Configuration.current;
  final _compiler = TestCompiler(
      p.join(p.current, '.dart_tool', 'test', 'incremental_kernel'));
  final _closeMemo = AsyncMemoizer<void>();
  final _tempDir = Directory.systemTemp.createTempSync('dart_test.vm.');

  @override
  Future<RunnerSuite?> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Map<String, Object?> message) async {
    assert(platform.runtime == Runtime.vm);

    _setupPauseAfterTests();

    MultiChannel outerChannel;
    var cleanupCallbacks = <void Function()>[];
    Isolate? isolate;
    if (platform.compiler == Compiler.exe) {
      var serverSocket = await ServerSocket.bind('localhost', 0);
      Process process;
      try {
        process =
            await _spawnExecutable(path, suiteConfig.metadata, serverSocket);
      } catch (error) {
        unawaited(serverSocket.close());
        rethrow;
      }
      process.stdout.listen(stdout.add);
      process.stderr.listen(stderr.add);
      var socket = await serverSocket.first;
      outerChannel = MultiChannel<Object?>(jsonSocketStreamChannel(socket));
      cleanupCallbacks
        ..add(serverSocket.close)
        ..add(process.kill);
    } else {
      var receivePort = ReceivePort();
      try {
        isolate = await _spawnIsolate(path, receivePort.sendPort,
            suiteConfig.metadata, platform.compiler);
        if (isolate == null) return null;
      } catch (error) {
        receivePort.close();
        rethrow;
      }
      outerChannel = MultiChannel(IsolateChannel.connectReceive(receivePort));
      cleanupCallbacks.add(isolate.kill);
    }
    cleanupCallbacks.add(outerChannel.sink.close);

    VmService? client;
    StreamSubscription<Event>? eventSub;
    // Typical test interaction will go across `channel`, `outerChannel` adds
    // additional communication directly between the test bootstrapping and this
    // platform to enable pausing after tests for debugging.
    var outerQueue = StreamQueue(outerChannel.stream);
    var channelId = (await outerQueue.next) as int;
    var channel = outerChannel.virtualChannel(channelId).transformStream(
        StreamTransformer.fromHandlers(handleDone: (sink) async {
      if (_shouldPauseAfterTests) {
        outerChannel.sink.add('debug');
        await outerQueue.next;
      }
      for (var fn in cleanupCallbacks) {
        fn();
      }
      unawaited(eventSub?.cancel());
      unawaited(client?.dispose());
      sink.close();
    }));

    Environment? environment;
    IsolateRef? isolateRef;
    if (_config.debug) {
      if (platform.compiler == Compiler.exe) {
        throw UnsupportedError(
            'Unable to debug tests compiled to `exe` (tried to debug $path with '
            'the `exe` compiler).');
      }
      var info =
          await Service.controlWebServer(enable: true, silenceOutput: true);
      // ignore: deprecated_member_use, Remove when SDK constraint is at 3.2.0
      var isolateID = Service.getIsolateID(isolate!)!;

      var libraryPath = (await absoluteUri(path)).toString();
      var serverUri = info.serverUri!;
      client = await vmServiceConnectUri(_wsUriFor(serverUri).toString());
      var isolateNumber = int.parse(isolateID.split('/').last);
      isolateRef = (await client.getVM())
          .isolates!
          .firstWhere((isolate) => isolate.number == isolateNumber.toString());
      await client.setName(isolateRef.id!, path);
      var libraryRef = (await client.getIsolate(isolateRef.id!))
          .libraries!
          .firstWhere((library) => library.uri == libraryPath);
      var url = _observatoryUrlFor(serverUri, isolateRef.id!, libraryRef.id!);
      environment = VMEnvironment(url, isolateRef, client);
    }

    environment ??= const PluginEnvironment();

    var controller = deserializeSuite(
        path, platform, suiteConfig, environment, channel.cast(), message,
        gatherCoverage: () => _gatherCoverage(environment!));

    if (isolateRef != null) {
      await client!.streamListen('Debug');
      eventSub = client.onDebugEvent.listen((event) {
        if (event.kind == EventKind.kResume) {
          controller.setDebugging(false);
        } else if (event.kind == EventKind.kPauseInterrupted ||
            event.kind == EventKind.kPauseBreakpoint ||
            event.kind == EventKind.kPauseException) {
          controller.setDebugging(true);
        }
      });
    }

    return await controller.suite;
  }

  @override
  Future close() => _closeMemo.runOnce(() => Future.wait([
        _compiler.dispose(),
        _tempDir.deleteWithRetry(),
      ]));

  /// Compiles [path] to a native executable and spawns it as a process.
  ///
  /// Sets up a communication channel as well by passing command line arguments
  /// for the host and port of [socket].
  Future<Process> _spawnExecutable(
      String path, Metadata suiteMetadata, ServerSocket socket) async {
    if (_config.suiteDefaults.precompiledPath != null) {
      throw UnsupportedError(
          'Precompiled native executable tests are not supported at this time');
    }
    var executable = await _compileToNative(path, suiteMetadata);
    return await Process.start(
        executable, [socket.address.host, socket.port.toString()]);
  }

  /// Compiles [path] to a native executable using `dart compile exe`.
  Future<String> _compileToNative(String path, Metadata suiteMetadata) async {
    var bootstrapPath = await _bootstrapNativeTestFile(
        path,
        suiteMetadata.languageVersionComment ??
            await rootPackageLanguageVersionComment);
    var output = File(p.setExtension(bootstrapPath, '.exe'));
    var processResult = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      bootstrapPath,
      '--output',
      output.path,
      '--packages',
      (await packageConfigUri).toFilePath(),
    ]);
    if (processResult.exitCode != 0 || !(await output.exists())) {
      throw LoadException(path, '''
exitCode: ${processResult.exitCode}
stdout: ${processResult.stdout}
stderr: ${processResult.stderr}''');
    }
    return output.path;
  }

  /// Spawns an isolate with the current configuration and passes it [message].
  ///
  /// This isolate connects an [IsolateChannel] to [message] and sends the
  /// serialized tests over that channel.
  ///
  /// Returns `null` if an exception occurs but [close] has already been called.
  Future<Isolate?> _spawnIsolate(String path, SendPort message,
      Metadata suiteMetadata, Compiler compiler) async {
    try {
      var precompiledPath = _config.suiteDefaults.precompiledPath;
      if (precompiledPath != null) {
        return _spawnPrecompiledIsolate(
            path, message, precompiledPath, compiler);
      }
      return switch (compiler) {
        Compiler.kernel => _spawnIsolateWithUri(
            await _compileToKernel(path, suiteMetadata), message),
        Compiler.source => _spawnIsolateWithUri(
            await _bootstrapIsolateTestFile(
                path,
                suiteMetadata.languageVersionComment ??
                    await rootPackageLanguageVersionComment),
            message),
        _ => throw StateError(
            'Unsupported compiler $compiler for the VM platform'),
      };
    } catch (_) {
      if (_closeMemo.hasRun) return null;
      rethrow;
    }
  }

  /// Compiles [path] to kernel and returns the uri to the compiled dill.
  Future<Uri> _compileToKernel(String path, Metadata suiteMetadata) async {
    final response =
        await _compiler.compile(await absoluteUri(path), suiteMetadata);
    var compiledDill = response.kernelOutputUri?.toFilePath();
    if (compiledDill == null || response.errorCount > 0) {
      throw LoadException(path, response.compilerOutput ?? 'unknown error');
    }
    return absoluteUri(compiledDill);
  }

  /// Runs [uri] in an isolate, passing [message].
  Future<Isolate> _spawnIsolateWithUri(Uri uri, SendPort message) async {
    return await Isolate.spawnUri(uri, [], message,
        packageConfig: await packageConfigUri, checked: true);
  }

  Future<Isolate> _spawnPrecompiledIsolate(String testPath, SendPort message,
      String precompiledPath, Compiler compiler) async {
    var testUri =
        await absoluteUri('${p.join(precompiledPath, testPath)}.vm_test.dart');
    testUri = testUri.replace(path: testUri.path.stripDriveLetterLeadingSlash);

    switch (compiler) {
      case Compiler.kernel:
        // Load `.dill` files from their absolute file path.
        var dillUri = (await Isolate.resolvePackageUri(testUri.replace(
            path:
                '${testUri.path.substring(0, testUri.path.length - '.dart'.length)}'
                '.vm.app.dill')))!;
        if (await File.fromUri(dillUri).exists()) {
          testUri = dillUri;
        }
        // TODO: Compile to kernel manually here? Otherwise we aren't compiling
        // with kernel when we technically should be, based on the compiler
        // setting.
        break;
      case Compiler.source:
        // Just leave test uri as is.
        break;
      default:
        throw StateError('Unsupported compiler for the VM platform $compiler.');
    }
    File? packageConfig =
        File(p.join(precompiledPath, '.dart_tool/package_config.json'));
    if (!(await packageConfig.exists())) {
      packageConfig = File(p.join(precompiledPath, '.packages'));
      if (!(await packageConfig.exists())) {
        packageConfig = null;
      }
    }
    return await Isolate.spawnUri(testUri, [], message,
        packageConfig: packageConfig?.uri, checked: true);
  }

  /// Bootstraps the test at [testPath] and writes its contents to a temporary
  /// file.
  ///
  /// Returns the [Uri] to the created file.
  Future<Uri> _bootstrapIsolateTestFile(
      String testPath, String languageVersionComment) async {
    var file = File(p.join(
        _tempDir.path, p.setExtension(testPath, '.bootstrap.isolate.dart')));
    if (!file.existsSync()) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(_bootstrapIsolateTestContents(
            await absoluteUri(testPath), languageVersionComment));
    }
    return file.uri;
  }

  /// Bootstraps the test at [testPath] for native execution and writes its
  /// contents to a temporary file.
  ///
  /// Returns the path to the created file.
  Future<String> _bootstrapNativeTestFile(
      String testPath, String languageVersionComment) async {
    var file = File(p.join(
        _tempDir.path, p.setExtension(testPath, '.bootstrap.native.dart')));
    if (!file.existsSync()) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(_bootstrapNativeTestContents(
            await absoluteUri(testPath), languageVersionComment));
    }
    return file.path;
  }
}

/// Creates bootstrap file contents for running [testUri] in a VM isolate.
String _bootstrapIsolateTestContents(
        Uri testUri, String languageVersionComment) =>
    '''
    $languageVersionComment
    import "dart:isolate";
    import "package:test_core/src/bootstrap/vm.dart";
    import "$testUri" as test;
    void main(_, SendPort sendPort) {
      internalBootstrapVmTest(() => test.main, sendPort);
    }
  ''';

/// Creates bootstrap file contents for running [testUri] as a native
/// executable.
String _bootstrapNativeTestContents(
        Uri testUri, String languageVersionComment) =>
    '''
    $languageVersionComment
    import "dart:isolate";
    import "package:test_core/src/bootstrap/vm.dart";
    import "$testUri" as test;
    void main(List<String> args) {
      internalBootstrapNativeTest(() => test.main, args);
    }
  ''';

Future<Map<String, dynamic>> _gatherCoverage(Environment environment) async {
  final isolateId = Uri.parse(environment.observatoryUrl!.fragment)
      .queryParameters['isolateId'];
  return await collect(environment.observatoryUrl!, false, false, false, {},
      isolateIds: {isolateId!});
}

Uri _wsUriFor(Uri observatoryUrl) =>
    observatoryUrl.replace(scheme: 'ws').resolve('ws');

Uri _observatoryUrlFor(Uri base, String isolateId, String id) => base.replace(
    fragment: Uri(
        path: '/inspect',
        queryParameters: {'isolateId': isolateId, 'objectId': id}).toString());

var _hasRegistered = false;
void _setupPauseAfterTests() {
  if (_hasRegistered) return;
  _hasRegistered = true;
  registerExtension('ext.test.pauseAfterTests', (_, __) async {
    _shouldPauseAfterTests = true;
    return ServiceExtensionResponse.result(jsonEncode({}));
  });
}
