// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.reporter.json;

import 'dart:async';
import 'dart:convert';

import '../../backend/live_test.dart';
import '../../frontend/expect.dart';
import '../../utils.dart';
import '../engine.dart';
import '../reporter.dart';
import '../version.dart';

/// A reporter that prints machine-readable JSON-formatted test results.
class JsonReporter implements Reporter {
  /// Whether to use verbose stack traces.
  final bool _verboseTrace;

  /// The engine used to run the tests.
  final Engine _engine;

  /// A stopwatch that tracks the duration of the full run.
  final _stopwatch = new Stopwatch();

  /// Whether we've started [_stopwatch].
  ///
  /// We can't just use `_stopwatch.isRunning` because the stopwatch is stopped
  /// when the reporter is paused.
  var _stopwatchStarted = false;

  /// Whether the reporter is paused.
  var _paused = false;

  /// The set of all subscriptions to various streams.
  final _subscriptions = new Set<StreamSubscription>();

  /// An expando that associates unique IDs with [LiveTest]s.
  final _ids = new Map<LiveTest, int>();

  /// The next ID to associate with a [LiveTest].
  var _nextID = 0;

  /// Watches the tests run by [engine] and prints their results as JSON.
  ///
  /// If [verboseTrace] is `true`, this will print core library frames.
  static JsonReporter watch(Engine engine, {bool verboseTrace: false}) {
    return new JsonReporter._(engine, verboseTrace: verboseTrace);
  }

  JsonReporter._(this._engine, {bool verboseTrace: false})
      : _verboseTrace = verboseTrace {
    _subscriptions.add(_engine.onTestStarted.listen(_onTestStarted));

    /// Convert the future to a stream so that the subscription can be paused or
    /// canceled.
    _subscriptions.add(_engine.success.asStream().listen(_onDone));

    _emit("start", {
      "protocolVersion": "0.1.0",
      "runnerVersion": testVersion
    });
  }

  void pause() {
    if (_paused) return;
    _paused = true;

    _stopwatch.stop();

    for (var subscription in _subscriptions) {
      subscription.pause();
    }
  }

  void resume() {
    if (!_paused) return;
    _paused = false;

    if (_stopwatchStarted) _stopwatch.start();

    for (var subscription in _subscriptions) {
      subscription.resume();
    }
  }

  void cancel() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// A callback called when the engine begins running [liveTest].
  void _onTestStarted(LiveTest liveTest) {
    if (!_stopwatchStarted) {
      _stopwatchStarted = true;
      _stopwatch.start();
    }

    var id = _nextID++;
    _ids[liveTest] = id;
    _emit("testStart", {
      "test": {
        "id": id,
        "name": liveTest.test.name, 
        "metadata": {
          "skip": liveTest.test.metadata.skip,
          "skipReason": liveTest.test.metadata.skipReason
        }
      }
    });

    /// Convert the future to a stream so that the subscription can be paused or
    /// canceled.
    _subscriptions.add(liveTest.onComplete.asStream().listen((_) =>
        _onComplete(liveTest)));

    _subscriptions.add(liveTest.onError.listen((error) =>
        _onError(liveTest, error.error, error.stackTrace)));

    _subscriptions.add(liveTest.onPrint.listen((line) {
      _emit("print", {
        "testID": id,
        "message": line
      });
    }));
  }

  /// A callback called when [liveTest] finishes running.
  void _onComplete(LiveTest liveTest) {
    _emit("testDone", {
      "testID": _ids[liveTest],
      "result": liveTest.state.result.toString(),
      "hidden": !_engine.liveTests.contains(liveTest)
    });
  }

  /// A callback called when [liveTest] throws [error].
  void _onError(LiveTest liveTest, error, StackTrace stackTrace) {
    _emit("error", {
      "testID": _ids[liveTest],
      "error": error.toString(),
      "stackTrace": terseChain(stackTrace, verbose: _verboseTrace).toString(),
      "isFailure": error is TestFailure
    });
  }

  /// A callback called when the engine is finished running tests.
  ///
  /// [success] will be `true` if all tests passed, `false` if some tests
  /// failed, and `null` if the engine was closed prematurely.
  void _onDone(bool success) {
    cancel();
    _stopwatch.stop();

    _emit("done", {"success": success});
  }

  /// Emits an event with the given type and attributes.
  void _emit(String type, Map attributes) {
    attributes["type"] = type;
    attributes["time"] = _stopwatch.elapsed.inMilliseconds;
    print(JSON.encode(attributes));
  }
}
