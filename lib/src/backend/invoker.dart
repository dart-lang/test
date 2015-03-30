// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.backend.invoker;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import '../frontend/expect.dart';
import '../utils.dart';
import 'live_test.dart';
import 'live_test_controller.dart';
import 'metadata.dart';
import 'state.dart';
import 'suite.dart';
import 'test.dart';

/// A test in this isolate.
class LocalTest implements Test {
  final String name;
  final Metadata metadata;

  /// The test body.
  final AsyncFunction _body;

  /// The callback used to clean up after the test.
  ///
  /// This is separated out from [_body] because it needs to run once the test's
  /// asynchronous computation has finished, even if that's different from the
  /// completion of the main body of the test.
  final AsyncFunction _tearDown;

  LocalTest(this.name, this.metadata, body(), {tearDown()})
      : _body = body,
        _tearDown = tearDown;

  /// Loads a single runnable instance of this test.
  LiveTest load(Suite suite) {
    var invoker = new Invoker._(suite, this);
    return invoker.liveTest;
  }
}

/// The class responsible for managing the lifecycle of a single local test.
///
/// The current invoker is accessible within the zone scope of the running test
/// using [Invoker.current]. It's used to track asynchronous callbacks and
/// report asynchronous errors.
class Invoker {
  /// The live test being driven by the invoker.
  ///
  /// This provides a view into the state of the test being executed.
  LiveTest get liveTest => _controller.liveTest;
  LiveTestController _controller;

  /// The test being run.
  LocalTest get _test => liveTest.test as LocalTest;

  /// Note that this is meaningless once [_onCompleteCompleter] is complete.
  var _outstandingCallbacks = 0;

  /// The completer to complete once the test body finishes.
  ///
  /// This is distinct from [_controller.completer] because a tear-down may need
  /// to run before the test is truly finished.
  final _completer = new Completer();

  /// The current invoker, or `null` if none is defined.
  ///
  /// An invoker is only set within the zone scope of a running test.
  static Invoker get current {
    // TODO(nweiz): Use a private symbol when dart2js supports it (issue 17526).
    return Zone.current[#unittest.invoker];
  }

  Invoker._(Suite suite, LocalTest test) {
    _controller = new LiveTestController(suite, test, _onRun);
  }

  /// Tells the invoker that there's a callback running that it should wait for
  /// before considering the test successful.
  ///
  /// Each call to [addOutstandingCallback] should be followed by a call to
  /// [removeOutstandingCallback] once the callbak is no longer running. Note
  /// that only successful tests wait for outstanding callbacks; as soon as a
  /// test experiences an error, any further calls to [addOutstandingCallback]
  /// or [removeOutstandingCallback] will do nothing.
  void addOutstandingCallback() {
    _outstandingCallbacks++;
  }

  /// Tells the invoker that a callback declared with [addOutstandingCallback]
  /// is no longer running.
  void removeOutstandingCallback() {
    _outstandingCallbacks--;

    if (_outstandingCallbacks != 0) return;
    if (_completer.isCompleted) return;

    // The test must be passing if we get here, because if there were an error
    // the completer would already be completed.
    assert(liveTest.state.result == Result.success);
    _completer.complete();
  }

  /// Notifies the invoker of an asynchronous error.
  ///
  /// Note that calling this explicitly is rarely necessary, since any
  /// otherwise-uncaught errors will be forwarded to the invoker anyway.
  void handleError(error, [StackTrace stackTrace]) {
    if (stackTrace == null) stackTrace = new Chain.current();

    var afterSuccess = liveTest.isComplete &&
        liveTest.state.result == Result.success;

    if (error is! TestFailure) {
      _controller.setState(const State(Status.complete, Result.error));
    } else if (liveTest.state.result != Result.error) {
      _controller.setState(const State(Status.complete, Result.failure));
    }

    _controller.addError(error, stackTrace);

    if (!_completer.isCompleted) _completer.complete();

    // If a test was marked as success but then had an error, that indicates
    // that it was poorly-written and could be flaky.
    if (!afterSuccess) return;
    handleError(
        "This test failed after it had already completed. Make sure to use "
            "[expectAsync]\n"
        "or the [completes] matcher when testing async code.",
        stackTrace);
  }

  /// The method that's run when the test is started.
  void _onRun() {
    _controller.setState(const State(Status.running, Result.success));

    Chain.capture(() {
      runZoned(() {
        // TODO(nweiz): Make the timeout configurable.
        // TODO(nweiz): Reset this timer whenever the user's code interacts with
        // the library.
        var timer = new Timer(new Duration(seconds: 30), () {
          if (liveTest.isComplete) return;
          handleError(
              new TimeoutException(
                  "Test timed out after 30 seconds.",
                  new Duration(seconds: 30)));
        });

        addOutstandingCallback();

        // Run the test asynchronously so that the "running" state change has a
        // chance to hit its event handler(s) before the test produces an error.
        // If an error is emitted before the first state change is handled, we
        // can end up with [onError] callbacks firing before the corresponding
        // [onStateChange], which violates the timing guarantees.
        new Future(_test._body)
            .then((_) => removeOutstandingCallback());

        // Explicitly handle an error here so that we can return the [Future].
        // If a [Future] returned from an error zone would throw an error
        // through the zone boundary, it instead never completes, and we want to
        // avoid that.
        _completer.future.then((_) {
          if (_test._tearDown == null) return null;
          return new Future.sync(_test._tearDown);
        }).catchError(Zone.current.handleUncaughtError).then((_) {
          timer.cancel();
          _controller.setState(
              new State(Status.complete, liveTest.state.result));

          // Use [Timer.run] here to avoid starving the DOM or other
          // non-microtask events.
          Timer.run(_controller.completer.complete);
        });
      },
          zoneSpecification: new ZoneSpecification(
              print: (self, parent, zone, line) => _controller.print(line)),
          zoneValues: {#unittest.invoker: this},
          onError: handleError);
    });
  }
}
