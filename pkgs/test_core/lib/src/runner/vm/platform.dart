// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test_api/backend.dart'; // ignore: deprecated_member_use
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:vm_service/vm_service.dart' hide Isolate;
import 'package:vm_service/vm_service_io.dart';

import '../../runner/configuration.dart';
import '../../runner/environment.dart';
import '../../runner/load_exception.dart';
import '../../runner/platform.dart';
import '../../runner/plugin/platform_helpers.dart';
import '../../runner/runner_suite.dart';
import '../../runner/suite.dart';
import '../../util/dart.dart' as dart;
import '../package_version.dart';
import 'environment.dart';

/// A platform that loads tests in isolates spawned within this Dart process.
class VMPlatform extends PlatformPlugin {
  /// The test runner configuration.
  final _config = Configuration.current;

  VMPlatform();

  @override
  StreamChannel loadChannel(String path, SuitePlatform platform) =>
      throw UnimplementedError();

  @override
  Future<RunnerSuite> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Object message) async {
    assert(platform.runtime == Runtime.vm);

    var receivePort = ReceivePort();
    Isolate isolate;
    try {
      isolate =
          await _spawnIsolate(path, receivePort.sendPort, suiteConfig.metadata);
    } catch (error) {
      receivePort.close();
      rethrow;
    }

    VmService? client;
    StreamSubscription<Event>? eventSub;
    var channel = IsolateChannel.connectReceive(receivePort)
        .transformStream(StreamTransformer.fromHandlers(handleDone: (sink) {
      isolate.kill();
      eventSub?.cancel();
      client?.dispose();
      sink.close();
    }));

    Environment? environment;
    IsolateRef? isolateRef;
    if (_config.debug) {
      // Print an empty line because the VM prints an "Observatory listening on"
      // line and we don't want that to end up on the same line as the reporter
      // info.
      if (_config.reporter == 'compact') stdout.writeln();

      var info = await Service.controlWebServer(enable: true);
      var isolateID = Service.getIsolateID(isolate)!;

      var libraryPath = p.toUri(p.absolute(path)).toString();
      client = await vmServiceConnectUri(_wsUriFor(info.serverUri.toString()));
      var isolateNumber = int.parse(isolateID.split('/').last);
      isolateRef = (await client.getVM())
          .isolates
          .firstWhere((isolate) => isolate.number == isolateNumber.toString());
      await client.setName(isolateRef.id, path);
      var libraryRef = (await client.getIsolate(isolateRef.id))
          .libraries
          .firstWhere((library) => library.uri == libraryPath);
      var url = _observatoryUrlFor(
          info.serverUri.toString(), isolateRef.id, libraryRef.id);
      environment = VMEnvironment(url, isolateRef, client);
    }

    environment ??= PluginEnvironment();

    var controller = deserializeSuite(
        path, platform, suiteConfig, environment, channel, message,
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

  /// Spawns an isolate and passes it [message].
  ///
  /// This isolate connects an [IsolateChannel] to [message] and sends the
  /// serialized tests over that channel.
  Future<Isolate> _spawnIsolate(
      String path, SendPort message, Metadata suiteMetadata) async {
    var precompiledPath = _config.suiteDefaults.precompiledPath;
    if (precompiledPath != null) {
      return _spawnPrecompiledIsolate(path, message, precompiledPath);
    } else if (_config.pubServeUrl != null) {
      return _spawnPubServeIsolate(path, message, _config.pubServeUrl!);
    } else {
      return _spawnDataIsolate(path, message, suiteMetadata);
    }
  }
}

Future<Isolate> _spawnDataIsolate(
    String path, SendPort message, Metadata suiteMetadata) async {
  return await dart.runInIsolate('''
    ${suiteMetadata.languageVersionComment ?? await rootPackageLanguageVersionComment}
    import "dart:isolate";

    import "package:test_core/src/bootstrap/vm.dart";

    import "${p.toUri(p.absolute(path))}" as test;

    void main(_, SendPort sendPort) {
      internalBootstrapVmTest(() => test.main, sendPort);
    }
  ''', message);
}

Future<Isolate> _spawnPrecompiledIsolate(
    String testPath, SendPort message, String precompiledPath) async {
  testPath = p.absolute(p.join(precompiledPath, testPath) + '.vm_test.dart');
  var dillTestpath =
      testPath.substring(0, testPath.length - '.dart'.length) + '.vm.app.dill';
  if (await File(dillTestpath).exists()) {
    testPath = dillTestpath;
  }
  return await Isolate.spawnUri(p.toUri(testPath), [], message,
      packageConfig: p.toUri(p.join(precompiledPath, '.packages')),
      checked: true);
}

Future<Map<String, dynamic>> _gatherCoverage(Environment environment) async {
  final isolateId = Uri.parse(environment.observatoryUrl!.fragment)
      .queryParameters['isolateId']!;
  return await collect(environment.observatoryUrl, false, false, false, {},
      isolateIds: {isolateId});
}

Future<Isolate> _spawnPubServeIsolate(
    String testPath, SendPort message, Uri pubServeUrl) async {
  var url = pubServeUrl.resolveUri(
      p.toUri(p.relative(testPath, from: 'test') + '.vm_test.dart'));

  try {
    return await Isolate.spawnUri(url, [], message, checked: true);
  } on IsolateSpawnException catch (error) {
    if (error.message.contains('OS Error: Connection refused') ||
        error.message.contains('The remote computer refused')) {
      throw LoadException(
          testPath,
          'Error getting $url: Connection refused\n'
          'Make sure "pub serve" is running.');
    } else if (error.message.contains('404 Not Found')) {
      throw LoadException(
          testPath,
          'Error getting $url: 404 Not Found\n'
          'Make sure "pub serve" is serving the test/ directory.');
    }

    throw LoadException(testPath, error);
  }
}

String _wsUriFor(String observatoryUrl) =>
    "ws:${observatoryUrl.split(':').sublist(1).join(':')}ws";

Uri _observatoryUrlFor(String base, String isolateId, String id) =>
    Uri.parse('$base#/inspect?isolateId=${Uri.encodeQueryComponent(isolateId)}&'
        'objectId=${Uri.encodeQueryComponent(id)}');
