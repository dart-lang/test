// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.iframe_listener;

import 'dart:async';
import 'dart:convert';
import 'dart:html' hide Metadata;

import '../../backend/declarer.dart';
import '../../backend/metadata.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../backend/test_platform.dart';
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
  static Future start(Function getMain()) async {
    var channel = _postMessageChannel();

    var main;
    try {
      main = getMain();
    } on NoSuchMethodError catch (_) {
      _sendLoadException(channel, "No top-level main() function defined.");
      // TODO(nweiz): Just "return;" when issue 23200 is fixed.
      return null;
    }

    if (main is! Function) {
      _sendLoadException(channel, "Top-level main getter is not a function.");
      // TODO(nweiz): Just "return;" when issue 23200 is fixed.
      return null;
    } else if (main is! AsyncFunction) {
      _sendLoadException(channel, "Top-level main() function takes arguments.");
      // TODO(nweiz): Just "return;" when issue 23200 is fixed.
      return null;
    }

    var declarer;
    try {
      declarer = new Declarer();
      await runZoned(() => new Future.sync(main), zoneValues: {
        #test.declarer: declarer
      }, zoneSpecification: new ZoneSpecification(print: (_, __, ___, line) {
        channel.sink.add({"type": "print", "line": line});
      }));
    } catch (error, stackTrace) {
      channel.sink.add({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
      // TODO(nweiz): Just "return;" when issue 23200 is fixed.
      return null;
    }

    var url = Uri.parse(window.location.href);
    var message = JSON.decode(Uri.decodeFull(url.fragment));
    var metadata = new Metadata.deserialize(message['metadata']);
    var browser = TestPlatform.find(message['browser']);

    var suite = new Suite(
        declarer.tests, platform: browser, metadata: metadata);
    new IframeListener._(suite)._listen(channel);

    // TODO(nweiz): Remove this when issue 23200 is fixed.
    return null;
  }

  /// Constructs a [MultiChannel] wrapping the `postMessage` communication with
  /// the host page.
  ///
  /// This [MultiChannel] corresponds to a [MultiChannel] in the server's
  /// [IframeTest] class.
  static MultiChannel _postMessageChannel() {
    var inputController = new StreamController(sync: true);
    var outputController = new StreamController(sync: true);

    window.onMessage.listen((message) {
      // A message on the Window can theoretically come from any website. It's
      // very unlikely that a malicious site would care about hacking someone's
      // unit tests, let alone be able to find the test server while it's
      // running, but it's good practice to check the origin anyway.
      if (message.origin != window.location.origin) return;
      message.stopPropagation();
      inputController.add(message.data);
    });

    outputController.stream.listen((data) {
      // TODO(nweiz): Stop manually adding href here once issue 22554 is
      // fixed.
      window.parent.postMessage({
        "href": window.location.href,
        "data": data
      }, window.location.origin);
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

  /// Runs [test] and sends the results across [sendPort].
  void _runTest(Test test, MultiChannel channel) {
    var liveTest = test.load(_suite);

    channel.stream.listen((message) {
      assert(message['command'] == 'close');
      liveTest.close();
    });

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

    liveTest.onPrint.listen((line) {
      print(line);
      channel.sink.add({"type": "print", "line": line});
    });

    liveTest.run().then((_) => channel.sink.add({"type": "complete"}));
  }
}
