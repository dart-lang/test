// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.iframe_test;

import '../../backend/live_test.dart';
import '../../backend/live_test_controller.dart';
import '../../backend/metadata.dart';
import '../../backend/state.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../util/stack_trace_mapper.dart';

/// A test in a running iframe.
class IframeTest implements Test {
  final String name;
  final Metadata metadata;

  /// The mapper used to map stack traces for errors coming from this test, or
  /// `null`.
  final StackTraceMapper _mapper;

  /// The channel used to communicate with the test's [IframeListener].
  final MultiChannel _channel;

  IframeTest(this.name, this.metadata, this._channel, {StackTraceMapper mapper})
      : _mapper = mapper;

  LiveTest load(Suite suite) {
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
      });
    }, () {
      // Ignore all future messages from the test and complete it immediately.
      // We don't need to tell it to run its tear-down because there's nothing a
      // browser test needs to clean up on the file system anyway.
      testChannel.sink.close();
      if (!controller.completer.isCompleted) controller.completer.complete();
    });
    return controller.liveTest;
  }

  Test change({String name, Metadata metadata}) {
    if (name == name && metadata == this.metadata) return this;
    if (name == null) name = this.name;
    if (metadata == null) metadata = this.metadata;
    return new IframeTest(name, metadata, _channel);
  }
}
