// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.isolate_test;

import 'dart:async';
import 'dart:isolate';

import '../../backend/live_test.dart';
import '../../backend/live_test_controller.dart';
import '../../backend/metadata.dart';
import '../../backend/state.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../util/remote_exception.dart';
import '../../utils.dart';

/// A test in another isolate.
class IsolateTest implements Test {
  final String name;
  final Metadata metadata;

  /// The port on which to communicate with the remote test.
  final SendPort _sendPort;

  IsolateTest(this.name, this.metadata, this._sendPort);

  /// Loads a single runnable instance of this test.
  LiveTest load(Suite suite) {
    var controller;

    // We get a new send port for communicating with the live test, since
    // [_sendPort] is only for communicating with the non-live test. This will
    // be non-null once the test starts running.
    var sendPortCompleter;

    var receivePort;
    controller = new LiveTestController(suite, this, () {
      controller.setState(const State(Status.running, Result.success));

      sendPortCompleter = new Completer();
      receivePort = new ReceivePort();
      _sendPort.send({
        'command': 'run',
        'reply': receivePort.sendPort
      });

      receivePort.listen((message) {
        if (message['type'] == 'started') {
          sendPortCompleter.complete(message['reply']);
        } else if (message['type'] == 'error') {
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
    }, () {
      // If the test has finished running, just disconnect the receive port. The
      // Dart process won't terminate if there are any live receive ports open.
      if (controller.completer.isCompleted) {
        receivePort.close();
        return;
      }

      invoke(() async {
        // If the test is still running, send it a message telling it to shut
        // down ASAP. This causes the [Invoker] to eagerly throw exceptions
        // whenever the test touches it.
        var sendPort = await sendPortCompleter.future;
        sendPort.send({'command': 'close'});
        await controller.completer.future;
        receivePort.close();
      });
    });
    return controller.liveTest;
  }

  Test change({String name, Metadata metadata}) {
    if (name == name && metadata == this.metadata) return this;
    if (name == null) name = this.name;
    if (metadata == null) metadata = this.metadata;
    return new IsolateTest(name, metadata, _sendPort);
  }
}
