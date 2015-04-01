// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.isolate_test;

import 'dart:isolate';

import '../../backend/live_test.dart';
import '../../backend/live_test_controller.dart';
import '../../backend/metadata.dart';
import '../../backend/state.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../util/remote_exception.dart';

/// A test in another isolate.
class IsolateTest implements Test {
  final String name;
  final Metadata metadata;

  /// The port on which to communicate with the remote test.
  final SendPort _sendPort;

  IsolateTest(this.name, this.metadata, this._sendPort);

  /// Loads a single runnable instance of this test.
  LiveTest load(Suite suite) {
    var receivePort;
    var controller;
    controller = new LiveTestController(suite, this, () {
      controller.setState(const State(Status.running, Result.success));

      receivePort = new ReceivePort();
      _sendPort.send({
        'command': 'run',
        'reply': receivePort.sendPort
      });

      receivePort.listen((message) {
        if (message['type'] == 'error') {
          var asyncError = RemoteException.deserialize(message['error']);
          controller.addError(asyncError.error, asyncError.stackTrace);
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
    }, onClose: () {
      if (receivePort != null) receivePort.close();
    });
    return controller.liveTest;
  }
}
