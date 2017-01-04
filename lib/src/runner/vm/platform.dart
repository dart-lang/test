// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:vm_service_client/vm_service_client.dart';

import '../../backend/test_platform.dart';
import '../../util/dart.dart' as dart;
import '../configuration.dart';
import '../configuration/suite.dart';
import '../environment.dart';
import '../load_exception.dart';
import '../plugin/environment.dart';
import '../plugin/platform.dart';
import '../plugin/platform_helpers.dart';
import '../runner_suite.dart';
import 'environment.dart';

/// A platform that loads tests in isolates spawned within this Dart process.
class VMPlatform extends PlatformPlugin {
  /// The test runner configuration.
  final _config = Configuration.current;

  VMPlatform();

  StreamChannel loadChannel(String path, TestPlatform platform) =>
      throw new UnimplementedError();

  Future<RunnerSuite> load(String path, TestPlatform platform,
      SuiteConfiguration suiteConfig) async {
    assert(platform == TestPlatform.vm);

    var receivePort = new ReceivePort();
    Isolate isolate;
    try {
      isolate = await _spawnIsolate(path, receivePort.sendPort);
    } catch (error) {
      receivePort.close();
      rethrow;
    }

    VMServiceClient client;
    var channel = new IsolateChannel.connectReceive(receivePort)
      .transformStream(new StreamTransformer.fromHandlers(handleDone: (sink) {
        // Once the connection is closed by either end, kill the isolate (and
        // the VM service client if we have one).
        isolate.kill();
        client?.close();
        sink.close();
      }));

    if (!_config.pauseAfterLoad) {
      var controller = await deserializeSuite(
          path, platform, suiteConfig, new PluginEnvironment(), channel);
      return controller.suite;
    }

    // Print an empty line because the VM prints an "Observatory listening on"
    // line and we don't want that to end up on the same line as the reporter
    // info.
    if (_config.reporter == 'compact') stdout.writeln();

    var info = await Service.controlWebServer(enable: true);
    var isolateID = Service.getIsolateID(isolate);

    client = new VMServiceClient.connect(info.serverUri);
    var isolateNumber = int.parse(isolateID.split("/").last);
    var vmIsolate = (await client.getVM()).isolates
        .firstWhere((isolate) => isolate.number == isolateNumber);
    await vmIsolate.setName(path);

    var library = (await vmIsolate.loadRunnable())
        .libraries[p.toUri(p.absolute(path))];
    var url = info.serverUri.resolveUri(library.observatoryUrl);
    var environment = new VMEnvironment(url, vmIsolate);
    var controller = await deserializeSuite(
        path, platform, suiteConfig, environment, channel);

    vmIsolate.onPauseOrResume.listen((event) {
      controller.setDebugging(event is! VMResumeEvent);
    });

    return controller.suite;
  }

  /// Spawns an isolate and passes it [message].
  ///
  /// This isolate connects an [IsolateChannel] to [message] and sends the
  /// serialized tests over that channel.
  Future<Isolate> _spawnIsolate(String path, SendPort message) async {
    if (_config.pubServeUrl == null) {
      return await dart.runInIsolate('''
        import "dart:isolate";

        import "package:stream_channel/stream_channel.dart";

        import "package:test/src/runner/plugin/remote_platform_helpers.dart";
        import "package:test/src/runner/vm/catch_isolate_errors.dart";

        import "${p.toUri(p.absolute(path))}" as test;

        void main(_, SendPort message) {
          var channel = serializeSuite(() {
            catchIsolateErrors();
            return test.main;
          });
          new IsolateChannel.connectSend(message).pipe(channel);
        }
      ''', message, checked: true);
    }

    var url = _config.pubServeUrl.resolveUri(
        p.toUri(p.relative(path, from: 'test') + '.vm_test.dart'));

    try {
      return await Isolate.spawnUri(url, [], message, checked: true);
    } on IsolateSpawnException catch (error) {
      if (error.message.contains("OS Error: Connection refused") ||
          error.message.contains("The remote computer refused")) {
        throw new LoadException(path,
            "Error getting $url: Connection refused\n"
            'Make sure "pub serve" is running.');
      } else if (error.message.contains("404 Not Found")) {
        throw new LoadException(path,
            "Error getting $url: 404 Not Found\n"
            'Make sure "pub serve" is serving the test/ directory.');
      }

      throw new LoadException(path, error);
    }
  }
}
