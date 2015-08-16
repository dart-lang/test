// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.isolate_listener;

import 'dart:isolate';
import 'dart:async';

import '../../backend/metadata.dart';
import '../../backend/suite.dart';
import 'vm_listener.dart';

/// A class that runs tests in a separate isolate and communicates the results
/// back to the main isolate.
class IsolateListener extends VMListener {
  /// Extracts metadata about all the tests in the function returned by
  /// [getMain] and sends information about them over [sendPort].
  ///
  /// The main function is wrapped in a closure so that we can handle it being
  /// undefined here rather than in the generated code.
  ///
  /// Once that's done, this starts listening for commands about which tests to
  /// run.
  ///
  /// [metadata] is the suite-level metadata defined at the top of the file.
  static Future start(SendPort sendPort, Metadata metadata, Function getMain()) {
    return VMListener.start(sendPort.send, metadata, getMain,
        (Suite suite) => new IsolateListener(suite));
  }

  IsolateListener(Suite suite) : super(suite);

  /// Send information about [suite] via [send] and start listening for
  /// commands to run the tests.
  void listen(MessageSink send) {
    var tests = [];
    for (var i = 0; i < suite.tests.length; i++) {
      var test = suite.tests[i];
      var receivePort = new ReceivePort();
      tests.add({
        "name": test.name,
        "metadata": test.metadata.serialize(),
        "sendPort": receivePort.sendPort
      });

      receivePort.listen((message) {
        assert(message['command'] == 'run');
        runTest(test, message['reply'].send);
      });
    }

    send({
      "type": "success",
      "tests": tests
    });
  }
}
