// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:test_api/src/backend/group.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/metadata.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; // ignore: implementation_imports
import 'package:test_api/src/util/remote_exception.dart'; // ignore: implementation_imports

import '../runner_suite.dart';
import '../environment.dart';
import '../suite.dart';
import '../configuration.dart';
import '../load_exception.dart';
import '../runner_test.dart';

/// A helper method for creating a [RunnerSuiteController] containing tests
/// that communicate over [channel].
///
/// This returns a controller so that the caller has a chance to control the
/// runner suite's debugging state based on plugin-specific logic.
///
/// If the suite is closed, this will close [channel].
///
/// The [message] parameter is an opaque object passed from the runner to
/// [PlatformPlugin.load]. Plugins shouldn't interact with it other than to pass
/// it on to [deserializeSuite].
///
/// If [mapper] is passed, it will be used to adjust stack traces for any errors
/// emitted by tests.
RunnerSuiteController deserializeSuite(
    String path,
    SuitePlatform platform,
    SuiteConfiguration suiteConfig,
    Environment environment,
    StreamChannel channel,
    Object message) {
  var disconnector = Disconnector();
  var suiteChannel = MultiChannel(channel.transform(disconnector));

  suiteChannel.sink.add({
    'type': 'initial',
    'platform': platform.serialize(),
    'metadata': suiteConfig.metadata.serialize(),
    'asciiGlyphs': Platform.isWindows,
    'path': path,
    'collectTraces': Configuration.current.reporter == 'json',
    'noRetry': Configuration.current.noRetry,
    'foldTraceExcept': Configuration.current.foldTraceExcept.toList(),
    'foldTraceOnly': Configuration.current.foldTraceOnly.toList(),
  }..addAll(message as Map<String, dynamic>));

  var completer = Completer<Group>();

  var loadSuiteZone = Zone.current;
  handleError(error, StackTrace stackTrace) {
    disconnector.disconnect();

    if (completer.isCompleted) {
      // If we've already provided a controller, send the error to the
      // LoadSuite. This will cause the virtual load test to fail, which will
      // notify the user of the error.
      loadSuiteZone.handleUncaughtError(error, stackTrace);
    } else {
      completer.completeError(error, stackTrace);
    }
  }

  suiteChannel.stream.listen(
      (response) {
        switch (response["type"] as String) {
          case "print":
            print(response["line"]);
            break;

          case "loadException":
            handleError(
                LoadException(path, response["message"]), Trace.current());
            break;

          case "error":
            var asyncError = RemoteException.deserialize(response["error"]);
            handleError(
                LoadException(path, asyncError.error), asyncError.stackTrace);
            break;

          case "success":
            var deserializer = _Deserializer(suiteChannel);
            completer.complete(
                deserializer.deserializeGroup(response["root"] as Map));
            break;
        }
      },
      onError: handleError,
      onDone: () {
        if (completer.isCompleted) return;
        completer.completeError(
            LoadException(path, "Connection closed before test suite loaded."),
            Trace.current());
      });

  return RunnerSuiteController(
      environment, suiteConfig, suiteChannel, completer.future, platform,
      path: path,
      onClose: () => disconnector.disconnect().catchError(handleError));
}

/// A utility class for storing state while deserializing tests.
class _Deserializer {
  /// The channel over which tests communicate.
  final MultiChannel _channel;

  _Deserializer(this._channel);

  /// Deserializes [group] into a concrete [Group].
  Group deserializeGroup(Map group) {
    var metadata = Metadata.deserialize(group['metadata']);
    return Group(
        group['name'] as String,
        (group['entries'] as List).map((entry) {
          var map = entry as Map;
          if (map['type'] == 'group') return deserializeGroup(map);
          return _deserializeTest(map);
        }),
        metadata: metadata,
        trace: group['trace'] == null
            ? null
            : Trace.parse(group['trace'] as String),
        setUpAll: _deserializeTest(group['setUpAll'] as Map),
        tearDownAll: _deserializeTest(group['tearDownAll'] as Map));
  }

  /// Deserializes [test] into a concrete [Test] class.
  ///
  /// Returns `null` if [test] is `null`.
  Test _deserializeTest(Map test) {
    if (test == null) return null;

    var metadata = Metadata.deserialize(test['metadata']);
    var trace =
        test['trace'] == null ? null : Trace.parse(test['trace'] as String);
    var testChannel = _channel.virtualChannel(test['channel'] as int);
    return RunnerTest(test['name'] as String, metadata, trace, testChannel);
  }
}
