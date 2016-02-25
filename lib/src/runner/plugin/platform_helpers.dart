// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../backend/group.dart';
import '../../backend/metadata.dart';
import '../../backend/test.dart';
import '../../backend/test_platform.dart';
import '../../util/io.dart';
import '../../util/remote_exception.dart';
import '../environment.dart';
import '../load_exception.dart';
import '../runner_suite.dart';
import '../runner_test.dart';

typedef StackTrace _MapTrace(StackTrace trace);

/// A helper method for creating a [RunnerSuiteController] containing tests
/// that communicate over [channel].
///
/// This returns a controller so that the caller has a chance to control the
/// runner suite's debugging state based on plugin-specific logic.
///
/// If the suite is closed, this will close [channel].
///
/// If [mapTrace] is passed, it will be used to adjust stack traces for any
/// errors emitted by tests.
Future<RunnerSuiteController> deserializeSuite(String path,
    TestPlatform platform, Metadata metadata, Environment environment,
    StreamChannel channel, {StackTrace mapTrace(StackTrace trace)}) async {
  if (mapTrace == null) mapTrace = (trace) => trace;

  var disconnector = new Disconnector();
  var suiteChannel = new MultiChannel(channel.transform(disconnector));

  suiteChannel.sink.add({
    'platform': platform.identifier,
    'metadata': metadata.serialize(),
    'os': platform == TestPlatform.vm ? currentOS.identifier : null
  });

  var completer = new Completer();

  handleError(error, stackTrace) {
    disconnector.disconnect();

    if (completer.isCompleted) {
      // If we've already provided a controller, send the error to the
      // LoadSuite. This will cause the virtual load test to fail, which will
      // notify the user of the error.
      Zone.current.handleUncaughtError(error, mapTrace(stackTrace));
    } else {
      completer.completeError(error, mapTrace(stackTrace));
    }
  }

  suiteChannel.stream.listen((response) {
    switch (response["type"]) {
      case "print":
        print(response["line"]);
        break;

      case "loadException":
        handleError(
            new LoadException(path, response["message"]),
            new Trace.current());
        break;

      case "error":
        var asyncError = RemoteException.deserialize(response["error"]);
        handleError(
            new LoadException(path, asyncError.error),
            mapTrace(asyncError.stackTrace));
        break;

      case "success":
        var deserializer = new _Deserializer(suiteChannel, mapTrace);
        completer.complete(deserializer.deserializeGroup(response["root"]));
        break;
    }
  }, onError: handleError, onDone: () {
    if (completer.isCompleted) return;
    completer.completeError(
        new LoadException(
            path, "Connection closed before test suite loaded."),
        new Trace.current());
  });

  return new RunnerSuiteController(
      environment,
      await completer.future,
      path: path,
      platform: platform,
      os: currentOS,
      onClose: disconnector.disconnect);
}

/// A utility class for storing state while deserializing tests.
class _Deserializer {
  /// The channel over which tests communicate.
  final MultiChannel _channel;

  /// The function used to errors' map stack traces.
  final _MapTrace _mapTrace;

  _Deserializer(this._channel, this._mapTrace);

  /// Deserializes [group] into a concrete [Group].
  Group deserializeGroup(Map group) {
    var metadata = new Metadata.deserialize(group['metadata']);
    return new Group(group['name'], group['entries'].map((entry) {
      if (entry['type'] == 'group') return deserializeGroup(entry);
      return _deserializeTest(entry);
    }),
        metadata: metadata,
        setUpAll: _deserializeTest(group['setUpAll']),
        tearDownAll: _deserializeTest(group['tearDownAll']));
  }

  /// Deserializes [test] into a concrete [Test] class.
  ///
  /// Returns `null` if [test] is `null`.
  Test _deserializeTest(Map test) {
    if (test == null) return null;

    var metadata = new Metadata.deserialize(test['metadata']);
    var testChannel = _channel.virtualChannel(test['channel']);
    return new RunnerTest(test['name'], metadata, testChannel, _mapTrace);
  }
}
