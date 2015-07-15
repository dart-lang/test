// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.isolate_listener;

import 'dart:isolate';
import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import '../../backend/declarer.dart';
import '../../backend/metadata.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../backend/test_platform.dart';
import '../../util/io.dart';
import '../../util/remote_exception.dart';
import '../../utils.dart';

/// A class that runs tests in a separate isolate and communicates the results
/// back to the main isolate.
class IsolateListener {
  /// The test suite to run.
  final Suite _suite;

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
  static Future start(SendPort sendPort, Metadata metadata, Function getMain())
      async {
    // Capture any top-level errors (mostly lazy syntax errors, since other are
    // caught below) and report them to the parent isolate. We set errors
    // non-fatal because otherwise they'll be double-printed.
    var errorPort = new ReceivePort();
    Isolate.current.setErrorsFatal(false);
    Isolate.current.addErrorListener(errorPort.sendPort);
    errorPort.listen((message) {
      // Masquerade as an IsoalteSpawnException because that's what this would
      // be if the error had been detected statically.
      var error = new IsolateSpawnException(message[0]);
      var stackTrace =
          message[1] == null ? new Trace([]) : new Trace.parse(message[1]);
      sendPort.send({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
    });

    var main;
    try {
      main = getMain();
    } on NoSuchMethodError catch (_) {
      _sendLoadException(sendPort, "No top-level main() function defined.");
      return;
    }

    if (main is! Function) {
      _sendLoadException(sendPort, "Top-level main getter is not a function.");
      return;
    } else if (main is! AsyncFunction) {
      _sendLoadException(
          sendPort, "Top-level main() function takes arguments.");
      return;
    }

    var declarer = new Declarer();
    try {
      await runZoned(() => new Future.sync(main), zoneValues: {
        #test.declarer: declarer
      }, zoneSpecification: new ZoneSpecification(print: (_, __, ___, line) {
        sendPort.send({"type": "print", "line": line});
      }));
    } catch (error, stackTrace) {
      sendPort.send({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
      return;
    }

    var suite = new Suite(declarer.tests,
        platform: TestPlatform.vm, os: currentOS, metadata: metadata);
    new IsolateListener._(suite)._listen(sendPort);
  }

  /// Sends a message over [sendPort] indicating that the tests failed to load.
  ///
  /// [message] should describe the failure.
  static void _sendLoadException(SendPort sendPort, String message) {
    sendPort.send({"type": "loadException", "message": message});
  }

  IsolateListener._(this._suite);

  /// Send information about [_suite] across [sendPort] and start listening for
  /// commands to run the tests.
  void _listen(SendPort sendPort) {
    var tests = [];
    for (var i = 0; i < _suite.tests.length; i++) {
      var test = _suite.tests[i];
      var receivePort = new ReceivePort();
      tests.add({
        "name": test.name,
        "metadata": test.metadata.serialize(),
        "sendPort": receivePort.sendPort
      });

      receivePort.listen((message) {
        assert(message['command'] == 'run');
        _runTest(test, message['reply']);
      });
    }

    sendPort.send({
      "type": "success",
      "tests": tests
    });
  }

  /// Runs [test] and sends the results across [sendPort].
  void _runTest(Test test, SendPort sendPort) {
    var liveTest = test.load(_suite);

    var receivePort = new ReceivePort();
    sendPort.send({"type": "started", "reply": receivePort.sendPort});

    receivePort.listen((message) {
      assert(message['command'] == 'close');
      receivePort.close();
      liveTest.close();
    });

    liveTest.onStateChange.listen((state) {
      sendPort.send({
        "type": "state-change",
        "status": state.status.name,
        "result": state.result.name
      });
    });

    liveTest.onError.listen((asyncError) {
      sendPort.send({
        "type": "error",
        "error": RemoteException.serialize(
            asyncError.error, asyncError.stackTrace)
      });
    });

    liveTest.onPrint.listen((line) =>
        sendPort.send({"type": "print", "line": line}));

    liveTest.run().then((_) => sendPort.send({"type": "complete"}));
  }
}
