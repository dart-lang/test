// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.suite;

import 'dart:async';

import 'package:async/async.dart';

import '../../backend/group.dart';
import '../../backend/metadata.dart';
import '../../backend/test.dart';
import '../../backend/test_platform.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../util/stack_trace_mapper.dart';
import '../../util/stream_channel.dart';
import '../../utils.dart';
import '../environment.dart';
import '../load_exception.dart';
import '../runner_suite.dart';
import 'iframe_test.dart';

/// Loads a [RunnerSuite] for a browser.
///
/// [channel] should connect to the iframe containing the suite, which should
/// eventually emit a message containing the suite's test information.
/// [environment], [path], [platform], and [onClose] are passed to the
/// [RunnerSuite]. If passed, [mapper] is used to reformat the test's stack
/// traces.
Future<RunnerSuite> loadBrowserSuite(StreamChannel channel,
    Environment environment, String path, {StackTraceMapper mapper,
    TestPlatform platform, AsyncFunction onClose}) async {
  // The controller for the returned suite. This is set once we've loaded the
  // information about the tests in the suite.
  var controller;

  // A timer that's reset whenever we receive a message from the browser.
  // Because the browser stops running code when the user is actively debugging,
  // this lets us detect whether they're debugging reasonably accurately.
  //
  // The duration should be short enough that the debugging console is open as
  // soon as the user is done setting breakpoints, but long enough that a test
  // doing a lot of synchronous work doesn't trigger a false positive.
  //
  // Start this canceled because we don't want it to start ticking until we get
  // some response from the iframe.
  var timer = new RestartableTimer(new Duration(seconds: 3), () {
    controller.setDebugging(true);
  })..cancel();

  // Even though [channel] is probably a [MultiChannel] already, create a
  // nested MultiChannel because the iframe will be using a channel wrapped
  // within the host's channel.
  var suiteChannel = new MultiChannel(channel.stream.map((message) {
    // Whenever we get a message, no matter which child channel it's for, we the
    // browser is still running code which means the using isn't debugging.
    if (controller != null) {
      timer.reset();
      controller.setDebugging(false);
    }

    return message;
  }), channel.sink);

  var response = await _getResponse(suiteChannel.stream)
      .timeout(new Duration(minutes: 1), onTimeout: () {
    suiteChannel.sink.close();
    throw new LoadException(
        path,
        "Timed out waiting for the test suite to connect.");
  });

  try {
    _validateResponse(path, response);
  } catch (_) {
    suiteChannel.sink.close();
    rethrow;
  }

  controller = new RunnerSuiteController(environment,
      _deserializeGroup(suiteChannel, response["root"], mapper),
      platform: platform, path: path,
      onClose: () {
    suiteChannel.sink.close();
    timer.cancel();
    return onClose == null ? null : onClose();
  });

  // Start the debugging timer counting down.
  timer.reset();
  return controller.suite;
}

/// Listens for responses from the iframe on [stream].
///
/// Returns the serialized representation of the the root group for the suite,
/// or a response indicating that an error occurred.
Future<Map> _getResponse(Stream stream) {
  var completer = new Completer();
  stream.listen((response) {
    if (response["type"] == "print") {
      print(response["line"]);
    } else if (response["type"] != "ping") {
      completer.complete(response);
    }
  }, onDone: () {
    if (!completer.isCompleted) completer.complete();
  });

  return completer.future;
}

/// Throws an error encoded in [response], if there is one.
///
/// [path] is used for the error's metadata.
Future _validateResponse(String path, Map response) {
  if (response == null) {
    throw new LoadException(
        path, "Connection closed before test suite loaded.");
  }

  if (response["type"] == "loadException") {
    throw new LoadException(path, response["message"]);
  }

  if (response["type"] == "error") {
    var asyncError = RemoteException.deserialize(response["error"]);
    return new Future.error(
        new LoadException(path, asyncError.error),
        asyncError.stackTrace);
  }

  return new Future.value();
}

/// Deserializes [group] into a concrete [Group] class.
Group _deserializeGroup(MultiChannel suiteChannel, Map group,
    [StackTraceMapper mapper]) {
  var metadata = new Metadata.deserialize(group['metadata']);
  return new Group(group['name'], group['entries'].map((entry) {
    if (entry['type'] == 'group') {
      return _deserializeGroup(suiteChannel, entry, mapper);
    }

    return _deserializeTest(suiteChannel, entry, mapper);
  }),
      metadata: metadata,
      setUpAll: _deserializeTest(suiteChannel, group['setUpAll'], mapper),
      tearDownAll:
          _deserializeTest(suiteChannel, group['tearDownAll'], mapper));
}

/// Deserializes [test] into a concrete [Test] class.
///
/// Returns `null` if [test] is `null`.
Test _deserializeTest(MultiChannel suiteChannel, Map test,
    [StackTraceMapper mapper]) {
  if (test == null) return null;

  var metadata = new Metadata.deserialize(test['metadata']);
  var testChannel = suiteChannel.virtualChannel(test['channel']);
  return new IframeTest(test['name'], metadata, testChannel,
      mapper: mapper);
}
