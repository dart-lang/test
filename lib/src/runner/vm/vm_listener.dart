// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.vm_listener;

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

abstract class VMListener {
  /// The test suite to run.
  final Suite suite;

  static Future start(MessageSink send, Metadata metadata, Function getMain(),
      VMListener createListener(Suite suite)) async {
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
      send({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
    });

    var main;
    try {
      main = getMain();
    } on NoSuchMethodError catch (_) {
      _sendLoadException(send, "No top-level main() function defined.");
      return;
    }

    if (main is! Function) {
      _sendLoadException(send, "Top-level main getter is not a function.");
      return;
    } else if (main is! AsyncFunction) {
      _sendLoadException(send, "Top-level main() function takes arguments.");
      return;
    }

    var declarer = new Declarer();
    try {
      await runZoned(() => new Future.sync(main), zoneValues: {
        #test.declarer: declarer
      }, zoneSpecification: new ZoneSpecification(print: (_, __, ___, line) {
        send({"type": "print", "line": line});
      }));
    } catch (error, stackTrace) {
      send({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
      return;
    }

    var suite = new Suite(declarer.tests,
        platform: TestPlatform.vm, os: currentOS, metadata: metadata);
    createListener(suite).listen(send);
  }

  /// Sends a message using [send] indicating that the tests failed to load.
  ///
  /// [message] should describe the failure.
  static void _sendLoadException(MessageSink send, String message) {
    send({"type": "loadException", "message": message});
  }

  void listen(MessageSink send);

  VMListener(this.suite);

  /// Runs [test] and sends the results via [send].
  void runTest(Test test, MessageSink send) {
    var liveTest = test.load(suite);

    var receivePort = new ReceivePort();
    send({"type": "started", "reply": receivePort.sendPort});

    receivePort.listen((message) {
      assert(message['command'] == 'close');
      receivePort.close();
      liveTest.close();
    });

    liveTest.onStateChange.listen((state) {
      send({
        "type": "state-change",
        "status": state.status.name,
        "result": state.result.name
      });
    });

    liveTest.onError.listen((asyncError) {
      send({
        "type": "error",
        "error": RemoteException.serialize(
            asyncError.error, asyncError.stackTrace)
      });
    });

    liveTest.onPrint.listen((line) =>
        send({"type": "print", "line": line}));

    liveTest.run().then((_) => send({"type": "complete"}));
  }
}
