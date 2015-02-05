// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.live_test_controller;

import 'dart:async';
import 'dart:collection';

import 'package:stack_trace/stack_trace.dart';

import 'live_test.dart';
import 'state.dart';
import 'suite.dart';
import 'test.dart';

/// An implementation of [LiveTest] that's controlled by a [LiveTestController].
class _LiveTest extends LiveTest {
  final LiveTestController _controller;

  Suite get suite => _controller._suite;

  Test get test => _controller._test;

  State get state => _controller._state;

  Stream<State> get onStateChange =>
      _controller._onStateChangeController.stream;

  List<AsyncError> get errors => new UnmodifiableListView(_controller._errors);

  Stream<AsyncError> get onError => _controller._onErrorController.stream;

  Future get onComplete => _controller.completer.future;

  Future run() => _controller._run();

  _LiveTest(this._controller);
}

/// A controller that drives a [LiveTest].
///
/// This is a utility class to make it easier for implementors of [Test] to
/// create the [LiveTest] returned by [Test.load]. The [LiveTest] is accessible
/// through [LiveTestController.liveTest].
///
/// This automatically handles some of [LiveTest]'s guarantees, but for the most
/// part it's the caller's responsibility to make sure everything gets
/// dispatched in the correct order.
class LiveTestController {
  /// The [LiveTest] controlled by [this].
  LiveTest get liveTest => _liveTest;
  LiveTest _liveTest;

  /// The test suite that's running [this].
  final Suite _suite;

  /// The test that's being run.
  final Test _test;

  /// The function that will actually start the test running.
  final Function _onRun;

  /// The list of errors caught by the test.
  final _errors = new List<AsyncError>();

  /// The current state of the test.
  var _state = const State(Status.pending, Result.success);

  /// The controller for [LiveTest.onStateChange].
  final _onStateChangeController = new StreamController<State>.broadcast();

  /// The controller for [LiveTest.onError].
  final _onErrorController = new StreamController<AsyncError>.broadcast();

  /// The completer for [LiveTest.onComplete];
  final completer = new Completer();

  /// Whether [run] has been called.
  var _runCalled = false;

  /// Creates a new controller for a [LiveTest].
  ///
  /// [test] is the test being run; [suite] is the suite that contains it.
  ///
  /// [onRun] is a function that will be called from [LiveTest.run]. It should
  /// start the test running. The controller takes care of ensuring that
  /// [LiveTest.run] isn't called more than once and that [LiveTest.onComplete]
  /// is returned.
  LiveTestController(this._suite, this._test, void onRun())
      : _onRun = onRun {
    _liveTest = new _LiveTest(this);
  }

  /// Adds an error to the [LiveTest].
  ///
  /// This both adds the error to [LiveTest.errors] and emits it via
  /// [LiveTest.onError]. [stackTrace] is automatically converted into a [Chain]
  /// if it's not one already.
  void addError(error, StackTrace stackTrace) {
    var asyncError = new AsyncError(error, new Chain.forTrace(stackTrace));
    _errors.add(asyncError);
    _onErrorController.add(asyncError);
  }

  /// Sets the current state of the [LiveTest] to [newState].
  ///
  /// If [newState] is different than the old state, this both sets
  /// [LiveTest.state] and emits the new state via [LiveTest.onStateChanged]. If
  /// it's not different, this does nothing.
  void setState(State newState) {
    if (_state == newState) return;
    _state = newState;
    _onStateChangeController.add(newState);
  }

  /// A wrapper for [_onRun] that ensures that it follows the guarantees for
  /// [LiveTest.run].
  Future _run() {
    if (_runCalled) {
      throw new StateError("LiveTest.run() may not be called more than once.");
    }
    _runCalled = true;

    _onRun();
    return liveTest.onComplete;
  }
}
