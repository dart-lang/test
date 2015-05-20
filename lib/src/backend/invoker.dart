// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.invoker;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import '../frontend/expect.dart';
import '../utils.dart';
import 'closed_exception.dart';
import 'live_test.dart';
import 'live_test_controller.dart';
import 'metadata.dart';
import 'outstanding_callback_counter.dart';
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

  Test change({String name, Metadata metadata}) {
    if (name == null) name = this.name;
    if (metadata == null) metadata = this.metadata;
    return new LocalTest(name, metadata, _body, tearDown: _tearDown);
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

  /// Whether the test has been closed.
  ///
  /// Once the test is closed, [expect] and [expectAsync] will throw
  /// [ClosedException]s whenever accessed to help the test stop executing as
  /// soon as possible.
  bool get closed => _closed;
  bool _closed = false;

  /// The test being run.
  LocalTest get _test => liveTest.test as LocalTest;

  /// The test metadata merged with the suite metadata.
  final Metadata metadata;

  /// The outstanding callback counter for the current zone.
  OutstandingCallbackCounter get _outstandingCallbacks {
    var counter = Zone.current[this];
    if (counter != null) return counter;
    throw new StateError("Can't add or remove outstanding callbacks outside "
        "of a test body.");
  }

  /// The current invoker, or `null` if none is defined.
  ///
  /// An invoker is only set within the zone scope of a running test.
  static Invoker get current {
    // TODO(nweiz): Use a private symbol when dart2js supports it (issue 17526).
    return Zone.current[#test.invoker];
  }

  Invoker._(Suite suite, LocalTest test)
      : metadata = suite.metadata.merge(test.metadata) {
    _controller = new LiveTestController(suite, test, _onRun, () {
      _closed = true;
    });
  }

  /// Tells the invoker that there's a callback running that it should wait for
  /// before considering the test successful.
  ///
  /// Each call to [addOutstandingCallback] should be followed by a call to
  /// [removeOutstandingCallback] once the callbak is no longer running. Note
  /// that only successful tests wait for outstanding callbacks; as soon as a
  /// test experiences an error, any further calls to [addOutstandingCallback]
  /// or [removeOutstandingCallback] will do nothing.
  ///
  /// Throws a [ClosedException] if this test has been closed.
  void addOutstandingCallback() {
    if (closed) throw new ClosedException();
    _outstandingCallbacks.addOutstandingCallback();
  }

  /// Tells the invoker that a callback declared with [addOutstandingCallback]
  /// is no longer running.
  void removeOutstandingCallback() =>
      _outstandingCallbacks.removeOutstandingCallback();

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
    _outstandingCallbacks.removeAllOutstandingCallbacks();

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

    var outstandingCallbacksForBody = new OutstandingCallbackCounter();

    // TODO(nweiz): Use async/await here once issue 23497 has been fixed in two
    // stable versions.
    Chain.capture(() {
      runZonedWithValues(() {
        // TODO(nweiz): Reset this timer whenever the user's code interacts
        // with the library.
        var timeout = metadata.timeout.apply(new Duration(seconds: 30));
        var timer = new Timer(timeout, () {
          if (liveTest.isComplete) return;
          handleError(
              new TimeoutException(
                  "Test timed out after ${niceDuration(timeout)}.", timeout));
        });

        // Run the test asynchronously so that the "running" state change has
        // a chance to hit its event handler(s) before the test produces an
        // error. If an error is emitted before the first state change is
        // handled, we can end up with [onError] callbacks firing before the
        // corresponding [onStateChange], which violates the timing
        // guarantees.
        new Future(_test._body)
            .then((_) => removeOutstandingCallback());

        _outstandingCallbacks.noOutstandingCallbacks.then((_) {
          if (_test._tearDown == null) return null;

          // Reset the outstanding callback counter to wait for callbacks from
          // the test's `tearDown` to complete.
          var outstandingCallbacksForTearDown = new OutstandingCallbackCounter();
          runZonedWithValues(() {
            new Future.sync(_test._tearDown)
              .then((_) => removeOutstandingCallback());
          }, onError: handleError, zoneValues: {
            this: outstandingCallbacksForTearDown
          });

          return outstandingCallbacksForTearDown.noOutstandingCallbacks;
        }).then((_) {
          timer.cancel();
          _controller.setState(
              new State(Status.complete, liveTest.state.result));

          // Use [Timer.run] here to avoid starving the DOM or other
          // non-microtask events.
          Timer.run(_controller.completer.complete);
        });
      }, zoneValues: {
        #test.invoker: this,
        // Use the invoker as a key so that multiple invokers can have different
        // outstanding callback counters at once.
        this: outstandingCallbacksForBody
      },
          zoneSpecification: new ZoneSpecification(
              print: (self, parent, zone, line) => _controller.print(line)),
          onError: handleError);
    });
  }
}
