// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.live_test_controller;

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

  Stream<String> get onPrint => _controller._onPrintController.stream;

  Future get onComplete => _controller.completer.future;

  Future run() => _controller._run();

  Future close() => _controller._close();

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

  /// A function to run when the test is closed.
  ///
  /// This may be `null`.
  final Function _onClose;

  /// The list of errors caught by the test.
  final _errors = new List<AsyncError>();

  /// The current state of the test.
  var _state = const State(Status.pending, Result.success);

  /// The controller for [LiveTest.onStateChange].
  ///
  /// This is synchronous to ensure that events are well-ordered across multiple
  /// streams.
  final _onStateChangeController = new StreamController<State>
      .broadcast(sync: true);

  /// The controller for [LiveTest.onError].
  ///
  /// This is synchronous to ensure that events are well-ordered across multiple
  /// streams.
  final _onErrorController = new StreamController<AsyncError>
      .broadcast(sync: true);

  /// The controller for [LiveTest.onPrint].
  ///
  /// This is synchronous to ensure that events are well-ordered across multiple
  /// streams.
  final _onPrintController = new StreamController<String>.broadcast(sync: true);

  /// The completer for [LiveTest.onComplete];
  final completer = new Completer();

  /// Whether [run] has been called.
  var _runCalled = false;

  /// Whether [close] has been called.
  bool get _isClosed => _onErrorController.isClosed;

  /// Creates a new controller for a [LiveTest].
  ///
  /// [test] is the test being run; [suite] is the suite that contains it.
  ///
  /// [onRun] is a function that's called from [LiveTest.run]. It should start
  /// the test running. The controller takes care of ensuring that
  /// [LiveTest.run] isn't called more than once and that [LiveTest.onComplete]
  /// is returned.
  ///
  /// [onClose] is a function that's called the first time [LiveTest.close] is
  /// called. It should clean up any resources that have been allocated for the
  /// test and ensure that the test finishes quickly if it's still running. It
  /// will only be called if [onRun] has been called first.
  LiveTestController(this._suite, this._test, void onRun(), void onClose())
      : _onRun = onRun,
        _onClose = onClose {
    _liveTest = new _LiveTest(this);
  }

  /// Adds an error to the [LiveTest].
  ///
  /// This both adds the error to [LiveTest.errors] and emits it via
  /// [LiveTest.onError]. [stackTrace] is automatically converted into a [Chain]
  /// if it's not one already.
  void addError(error, StackTrace stackTrace) {
    if (_isClosed) return;

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
    if (_isClosed) return;
    if (_state == newState) return;

    _state = newState;
    _onStateChangeController.add(newState);
  }

  /// Emits a line printed by the test over [LiveTest.onPrint].
  void print(String line) => _onPrintController.add(line);

  /// A wrapper for [_onRun] that ensures that it follows the guarantees for
  /// [LiveTest.run].
  Future _run() {
    if (_runCalled) {
      throw new StateError("LiveTest.run() may not be called more than once.");
    } else if (_isClosed) {
      throw new StateError("LiveTest.run() may not be called for a closed "
          "test.");
    }
    _runCalled = true;

    _onRun();
    return liveTest.onComplete;
  }

  /// A wrapper for [_onClose] that ensures that all controllers are closed.
  Future _close() {
    if (_isClosed) return completer.future;

    _onStateChangeController.close();
    _onErrorController.close();

    if (_runCalled) {
      _onClose();
    } else {
      completer.complete();
    }

    return completer.future;
  }
}
