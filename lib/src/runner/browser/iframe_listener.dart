// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.iframe_listener;

import 'dart:async';
import 'dart:html';

import '../../backend/declarer.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../utils.dart';

// TODO(nweiz): test this once we can run browser tests.
/// A class that runs tests in a separate iframe.
///
/// This indirectly communicates with the test server. It uses `postMessage` to
/// relay communication through the host page, which has a WebSocket connection
/// to the test server.
class IframeListener {
  /// The test suite to run.
  final Suite _suite;

  /// Extracts metadata about all the tests in the function returned by
  /// [getMain] and sends information about them over the `postMessage`
  /// connection.
  ///
  /// The main function is wrapped in a closure so that we can handle it being
  /// undefined here rather than in the generated code.
  ///
  /// Once that's done, this starts listening for commands about which tests to
  /// run.
  static void start(Function getMain()) {
    var channel = _postMessageChannel();

    var main;
    try {
      main = getMain();
    } on NoSuchMethodError catch (_) {
      _sendLoadException(channel, "No top-level main() function defined.");
      return;
    }

    if (main is! Function) {
      _sendLoadException(channel, "Top-level main getter is not a function.");
      return;
    } else if (main is! AsyncFunction) {
      _sendLoadException(channel, "Top-level main() function takes arguments.");
      return;
    }

    var declarer = new Declarer();
    try {
      runZoned(main, zoneValues: {#unittest.declarer: declarer});
    } catch (error, stackTrace) {
      channel.sink.add({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
      return;
    }

    new IframeListener._(new Suite(declarer.tests))._listen(channel);
  }

  /// Constructs a [MultiChannel] wrapping the `postMessage` communication with
  /// the host page.
  ///
  /// This [MultiChannel] corresponds to a [MultiChannel] in the server's
  /// [IframeTest] class.
  static MultiChannel _postMessageChannel() {
    var inputController = new StreamController(sync: true);
    var outputController = new StreamController(sync: true);

    // Wait for the first message, which indicates the source [Window] to which
    // we should send further communication.
    var first = true;
    window.onMessage.listen((message) {
      // A message on the Window can theoretically come from any website. It's
      // very unlikely that a malicious site would care about hacking someone's
      // unit tests, let alone be able to find the unittest server while it's
      // running, but it's good practice to check the origin anyway.
      if (message.origin != window.location.origin) return;
      message.stopPropagation();

      if (!first) {
        inputController.add(message.data);
        return;
      }

      outputController.stream.listen((data) {
        // TODO(nweiz): Stop manually adding href here once issue 22554 is
        // fixed.
        message.source.postMessage({
          "href": window.location.href,
          "data": data
        }, window.location.origin);
      });
      first = false;
    });

    return new MultiChannel(inputController.stream, outputController.sink);
  }

  /// Sends a message over [channel] indicating that the tests failed to load.
  ///
  /// [message] should describe the failure.
  static void _sendLoadException(MultiChannel channel, String message) {
    channel.sink.add({"type": "loadException", "message": message});
  }

  IframeListener._(this._suite);

  /// Send information about [_suite] across [channel] and start listening for
  /// commands to run the tests.
  void _listen(MultiChannel channel) {
    var tests = [];
    for (var i = 0; i < _suite.tests.length; i++) {
      var test = _suite.tests[i];
      var testChannel = channel.virtualChannel();
      tests.add({
        "name": test.name,
        "metadata": test.metadata.serialize(),
        "channel": testChannel.id
      });

      testChannel.stream.listen((message) {
        assert(message['command'] == 'run');
        _runTest(test, channel.virtualChannel(message['channel']));
      });
    }

    channel.sink.add({
      "type": "success",
      "tests": tests
    });
  }

  /// Runs [test] and send the results across [sendPort].
  void _runTest(Test test, MultiChannel channel) {
    var liveTest = test.load(_suite);

    liveTest.onStateChange.listen((state) {
      channel.sink.add({
        "type": "state-change",
        "status": state.status.name,
        "result": state.result.name
      });
    });

    liveTest.onError.listen((asyncError) {
      channel.sink.add({
        "type": "error",
        "error": RemoteException.serialize(
            asyncError.error, asyncError.stackTrace)
      });
    });

    liveTest.run().then((_) => channel.sink.add({"type": "complete"}));
  }
}
