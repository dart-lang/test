// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test_api/backend.dart'
    show Metadata, RemoteException, SuitePlatform;
import 'package:test_api/src/backend/group.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/live_test_controller.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/message.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/state.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; // ignore: implementation_imports

import 'spawn_hybrid.dart';

/// A test running remotely, controlled by a stream channel.
class RunnerTest extends Test {
  @override
  final String name;
  @override
  final Metadata metadata;
  @override
  final Trace? trace;

  /// The channel used to communicate with the test's `RemoteListener`.
  final MultiChannel _channel;

  RunnerTest(this.name, this.metadata, this.trace, this._channel);

  @override
  LiveTest load(Suite suite, {Iterable<Group>? groups}) {
    late final LiveTestController controller;
    late final VirtualChannel testChannel;
    controller = LiveTestController(suite, this, () {
      controller.setState(const State(Status.running, Result.success));

      testChannel = _channel.virtualChannel();
      _channel.sink.add({'command': 'run', 'channel': testChannel.id});

      testChannel.stream.listen((message) {
        final msg = message as Map;
        switch (msg['type'] as String) {
          case 'error':
            var asyncError = RemoteException.deserialize(
                msg['error'] as Map<String, dynamic>);
            var stackTrace = asyncError.stackTrace;
            controller.addError(asyncError.error, stackTrace);
            break;

          case 'state-change':
            controller.setState(State(Status.parse(msg['status'] as String),
                Result.parse(msg['result'] as String)));
            break;

          case 'message':
            controller.message(Message(
                MessageType.parse(msg['message-type'] as String),
                msg['text'] as String));
            break;

          case 'complete':
            controller.completer.complete();
            break;

          case 'spawn-hybrid-uri':
            // When we kill the isolate that the test lives in, that will close
            // this virtual channel and cause the spawned isolate to close as
            // well.
            spawnHybridUri(msg['url'] as String, msg['message'], suite).pipe(
                testChannel.virtualChannel((msg['channel'] as num).toInt()));
            break;
        }
      }, onDone: () {
        // When the test channel closes—presumably because the browser
        // closed—mark the test as complete no matter what.
        if (controller.completer.isCompleted) return;
        controller.completer.complete();
      });
    }, () {
      // If the test has finished running, just disconnect the channel.
      if (controller.completer.isCompleted) {
        testChannel.sink.close();
        return;
      }

      unawaited(() async {
        // If the test is still running, send it a message telling it to shut
        // down ASAP. This causes the [Invoker] to eagerly throw exceptions
        // whenever the test touches it.
        testChannel.sink.add({'command': 'close'});
        await controller.completer.future;
        await testChannel.sink.close();
      }());
    }, groups: groups);
    return controller;
  }

  @override
  Test? forPlatform(SuitePlatform platform) {
    if (!metadata.testOn.evaluate(platform)) return null;
    return RunnerTest(name, metadata.forPlatform(platform), trace, _channel);
  }
}
