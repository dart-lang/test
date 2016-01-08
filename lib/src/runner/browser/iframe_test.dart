// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.iframe_test;

import '../../backend/group.dart';
import '../../backend/live_test.dart';
import '../../backend/live_test_controller.dart';
import '../../backend/metadata.dart';
import '../../backend/operating_system.dart';
import '../../backend/state.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../backend/test_platform.dart';
import '../../utils.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../util/stack_trace_mapper.dart';

/// A test in a running iframe.
class IframeTest extends Test {
  final String name;
  final Metadata metadata;

  /// The mapper used to map stack traces for errors coming from this test, or
  /// `null`.
  final StackTraceMapper _mapper;

  /// The channel used to communicate with the test's [IframeListener].
  final MultiChannel _channel;

  IframeTest(this.name, this.metadata, this._channel, {StackTraceMapper mapper})
      : _mapper = mapper;

  LiveTest load(Suite suite, {Iterable<Group> groups}) {
    var controller;
    var testChannel;
    controller = new LiveTestController(suite, this, () {
      controller.setState(const State(Status.running, Result.success));

      testChannel = _channel.virtualChannel();
      _channel.sink.add({
        'command': 'run',
        'channel': testChannel.id
      });

      testChannel.stream.listen((message) {
        if (message['type'] == 'error') {
          var asyncError = RemoteException.deserialize(message['error']);

          var stackTrace = asyncError.stackTrace;
          if (_mapper != null) stackTrace = _mapper.mapStackTrace(stackTrace);

          controller.addError(asyncError.error, stackTrace);
        } else if (message['type'] == 'state-change') {
          controller.setState(
              new State(
                  new Status.parse(message['status']),
                  new Result.parse(message['result'])));
        } else if (message['type'] == 'print') {
          controller.print(message['line']);
        } else {
          assert(message['type'] == 'complete');
          controller.completer.complete();
        }
      }, onDone: () {
        // When the test channel closes—presumably becuase the browser
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

      invoke(() async {
        // If the test is still running, send it a message telling it to shut
        // down ASAP. This causes the [Invoker] to eagerly throw exceptions
        // whenever the test touches it.
        testChannel.sink.add({'command': 'close'});
        await controller.completer.future;
        testChannel.sink.close();
      });
    }, groups: groups);
    return controller.liveTest;
  }

  Test forPlatform(TestPlatform platform, {OperatingSystem os}) {
    if (!metadata.testOn.evaluate(platform, os: os)) return null;
    return new IframeTest(
        name, metadata.forPlatform(platform, os: os), _channel,
        mapper: _mapper);
  }
}
