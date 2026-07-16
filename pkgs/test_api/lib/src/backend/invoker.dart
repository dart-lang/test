// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import 'closed_exception.dart';
import 'declarer.dart';
import 'group.dart';
import 'live_test.dart';
import 'live_test_controller.dart';
import 'message.dart';
import 'metadata.dart';
import 'state.dart';
import 'suite.dart';
import 'suite_platform.dart';
import 'test.dart';
import 'test_failure.dart';
import 'test_location.dart';
import 'zones.dart';
import 'util/pretty_print.dart';

/// A test in this isolate.
class LocalTest extends Test {
  @override
  final String name;

  @override
  final Metadata metadata;

  @override
  final Trace? trace;

  @override
  final TestLocation? location;

  /// Whether this is a test defined using `setUpAll()` or `tearDownAll()`.
  final bool isScaffoldAll;

  /// The test body.
  final FutureOr<void> Function() _body;

  /// Whether the test is run in its own error zone.
  final bool _guarded;

  /// Creates a new [LocalTest].
  ///
  /// If [guarded] is `true`, the test is run in its own error zone, and any
  /// errors that escape that zone cause the test to fail. If it's `false`, it's
  /// the caller's responsibility to invoke [LiveTest.run] in the context of a
  /// call to [Invoker.guard].
  LocalTest(
    this.name,
    this.metadata,
    this._body, {
    this.trace,
    this.location,
    bool guarded = true,
    this.isScaffoldAll = false,
  }) : _guarded = guarded;

  LocalTest._(
    this.name,
    this.metadata,
    this._body,
    this.trace,
    this.location,
    this._guarded,
    this.isScaffoldAll,
  );

  /// Loads a single runnable instance of this test.
  @override
  LiveTest load(Suite suite, {Iterable<Group>? groups}) {
    var invoker = Invoker._(suite, this, groups: groups, guarded: _guarded);
    return invoker.liveTest;
  }

  @override
  Test? forPlatform(SuitePlatform platform) {
    if (!metadata.testOn.evaluate(platform)) return null;
    return LocalTest._(
      name,
      metadata.forPlatform(platform),
      _body,
      trace,
      location,
      _guarded,
      isScaffoldAll,
    );
  }

  @override
  Test? filter(bool Function(Test) callback) {
    if (callback(this)) {
      // filter() always returns new copies because they need to be attached
      // to their new parents.
      return clone();
    }

    return null;
  }

  @override
  Test clone() {
    return LocalTest._(
      name,
      metadata,
      _body,
      trace,
      location,
      _guarded,
      isScaffoldAll,
    );
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
  LiveTest get liveTest => _controller;
  late final LiveTestController _controller;

  /// Whether to run this test in its own error zone.
  final bool _guarded;

  /// Whether the user code is allowed to interact with the invoker despite it
  /// being closed.
  ///
  /// A test is generally closed because the runner is shutting down (in
  /// response to a signal) or because the test's suite is finished.
  /// Typically calls to [addTearDown] and [addOutstandingCallback] are only
  /// allowed before the test is closed. Tear down callbacks, however, are
  /// allowed to perform these interactions to facilitate resource cleanup on a
  /// best-effort basis, so the invoker is made to appear open only within the
  /// zones running the teardown callbacks.
  /// Whether this invoker is executing tear-down callbacks.
  bool get _forceOpen => _isExecutingTearDown;
  bool _isExecutingTearDown = false;

  /// Whether the test has been closed.
  ///
  /// Once the test is closed, [expect] and [expectAsync] will throw
  /// [ClosedException]s whenever accessed to help the test stop executing as
  /// soon as possible.
  bool get closed => !_forceOpen && _onCloseCompleter.isCompleted;

  /// A future that completes once the test has been closed.
  Future<void> get onClose => _onCloseCompleter.future;
  final _onCloseCompleter = Completer<void>();

  /// The test being run.
  LocalTest get _test => liveTest.test as LocalTest;

  /// The outstanding callback counter for the current zone.
  _AsyncCounter get _outstandingCallbacks {
    var counter = _currentCounter;
    if (counter != null) return counter;
    throw StateError(
      "Can't add or remove outstanding callbacks outside "
      'of a test body.',
    );
  }

  _AsyncCounter? _currentCounter;

  /// All the zones created by [_waitForOutstandingCallbacks], in the order they
  /// were created.
  ///
  /// This is used to throw timeout errors in the most recent zone.
  final _outstandingCallbackZones = <Zone>[];

  /// The cached error zone for this Invoker, keyed by its baseZone.
  Zone? _errorZone;

  /// The main execution zone for this test in [_onRun].
  Zone? _mainExecutionZone;

  /// The Completer for the currently executing robust callback via [runRobustly].
  Completer<bool>? _currentRobustCompleter;

  /// Whether to complete [_currentRobustCompleter] immediately on an uncaught async error.
  bool _completeOnAsyncError = true;

  /// The number of times this [liveTest] has been run.
  int _runCount = 0;

  /// The [ZoneSpecification] to use for executing callbacks for this invoker.
  late final ZoneSpecification _cachedZoneSpecification = ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stackTrace) {
      var invoker = zone[#test.invoker] as Invoker?;
      if (invoker != null) {
        invoker._handleError(zone, error, stackTrace);
        var completer = invoker._currentRobustCompleter;
        if (completer != null && !completer.isCompleted) {
          if (invoker._completeOnAsyncError) {
            completer.complete(false);
          }
        }
      } else {
        _handleError(zone, error, stackTrace);
        var completer = _currentRobustCompleter;
        if (completer != null && !completer.isCompleted) {
          if (_completeOnAsyncError) {
            completer.complete(false);
          }
        }
      }
    },
    print: (self, parent, zone, line) {
      _print(line);
    },
  );

  ZoneSpecification get zoneSpecification => _cachedZoneSpecification;

  /// The current invoker, or `null` if none is defined.
  ///
  /// An invoker is only set within the zone scope of a running test.
  static Invoker? get current {
    // TODO(nweiz): Use a private symbol when dart2js supports it (issue 17526).
    return Zone.current[#test.invoker] as Invoker?;
  }

  /// Runs [callback] in a zone where unhandled errors from [LiveTest]s are
  /// caught and dispatched to the appropriate [Invoker].
  static T? guard<T>(T Function() callback) => runZoned<T?>(
    callback,
    zoneSpecification: ZoneSpecification(
      // Use [handleUncaughtError] rather than [onError] so we can
      // capture [zone] and with it the outstanding callback counter for
      // the zone in which [error] was thrown.
      handleUncaughtError: (self, _, zone, error, stackTrace) {
        var invoker = zone[#test.invoker] as Invoker?;
        if (invoker != null) {
          self.parent!.run(() => invoker._handleError(zone, error, stackTrace));
        } else {
          self.parent!.handleUncaughtError(error, stackTrace);
        }
      },
    ),
  );

  /// The timer for tracking timeouts.
  ///
  /// This will be `null` until the test starts running.
  Timer? _timeoutTimer;

  /// The tear-down functions to run when this test finishes.
  final _tearDowns = <CapturedCallback>[];

  /// Messages to print if and when this test fails.
  final _printsOnFailure = <String>[];

  Invoker._(
    Suite suite,
    LocalTest test, {
    Iterable<Group>? groups,
    bool guarded = true,
  }) : _guarded = guarded {
    _controller = LiveTestController(
      suite,
      test,
      _onRun,
      _onCloseCompleter.complete,
      groups: groups,
    );
  }

  /// Runs [callback] after this test completes.
  ///
  /// The [callback] may return a [Future]. Like all tear-downs, callbacks are
  /// run in the reverse of the order they're declared.
  void addTearDown(dynamic callback) {
    if (closed) throw ClosedException();

    CapturedCallback captured;
    if (callback is CapturedCallback) {
      captured = callback;
    } else if (callback is Function) {
      captured = CapturedCallback(callback, Zone.current);
    } else {
      throw ArgumentError(
        'Tear-down callback must be a Function or CapturedCallback',
      );
    }

    if (_test.isScaffoldAll) {
      Declarer.current!.addTearDownAll(captured);
    } else {
      _tearDowns.add(captured);
    }
  }

  /// Tells the invoker that there's a callback running that it should wait for
  /// before considering the test successful.
  ///
  /// Each call to [addOutstandingCallback] should be followed by a call to
  /// [removeOutstandingCallback] once the callback is no longer running. Note
  /// that only successful tests wait for outstanding callbacks; as soon as a
  /// test experiences an error, any further calls to [addOutstandingCallback]
  /// or [removeOutstandingCallback] will do nothing.
  ///
  /// Throws a [ClosedException] if this test has been closed.
  void addOutstandingCallback() {
    if (closed) throw ClosedException();
    _outstandingCallbacks.increment();
  }

  /// Tells the invoker that a callback declared with [addOutstandingCallback]
  /// is no longer running.
  void removeOutstandingCallback() {
    heartbeat();
    _outstandingCallbacks.decrement();
  }

  /// Run [tearDowns] in reverse order.
  ///
  /// An exception thrown in a tearDown callback will cause the test to fail, if
  /// it isn't already failing, but it won't prevent the remaining callbacks
  /// from running. This invoker will not be closeable within the zone that the
  /// teardowns are running in.
  Future<void> runTearDowns(List<dynamic> tearDowns) async {
    heartbeat();
    var oldForceOpen = _isExecutingTearDown;
    _isExecutingTearDown = true;
    try {
      while (tearDowns.isNotEmpty) {
        var tearDown = tearDowns.removeLast();

        CapturedCallback captured;
        if (tearDown is CapturedCallback) {
          captured = tearDown;
        } else if (tearDown is Function) {
          captured = CapturedCallback(tearDown, Zone.current);
        } else {
          throw ArgumentError(
            'Tear-down callback must be a Function or CapturedCallback',
          );
        }

        addOutstandingCallback();
        var completer = Completer<void>();

        _waitForOutstandingCallbacks(() {
          runRobustly(
            captured.zone,
            captured.fn as FutureOr<dynamic> Function(),
          ).whenComplete(() {
            if (!completer.isCompleted) completer.complete();
          });
        }).then((_) => removeOutstandingCallback()).unawaited;

        await completer.future;
      }
    } finally {
      _isExecutingTearDown = oldForceOpen;
    }
  }

  /// Runs [fn] and completes once [fn] and all outstanding callbacks registered
  /// within [fn] have completed.
  ///
  /// Outstanding callbacks registered within [fn] will *not* be registered as
  /// outstanding callback outside of [fn].
  Future<void> _waitForOutstandingCallbacks(FutureOr<void> Function() fn) {
    heartbeat();

    var counter = _AsyncCounter();
    var oldCounter = _currentCounter;
    _currentCounter = counter;

    Zone? zone;
    zone = Zone.current.fork();
    _outstandingCallbackZones.add(zone);

    zone.run(() async {
      try {
        await fn();
      } finally {
        counter.decrement();
      }
    });

    return counter.onZero.whenComplete(() {
      _outstandingCallbackZones.remove(zone);
      _currentCounter = oldCounter;
    });
  }

  /// Notifies the invoker that progress is being made.
  ///
  /// Each heartbeat resets the timeout timer. This helps ensure that
  /// long-running tests that still make progress don't time out.
  void heartbeat() {
    if (liveTest.isComplete) return;
    if (_timeoutTimer != null) _timeoutTimer!.cancel();
    if (liveTest.suite.ignoreTimeouts == true) return;

    const defaultTimeout = Duration(seconds: 30);
    var timeout = liveTest.test.metadata.timeout.apply(defaultTimeout);
    if (timeout == null) return;
    String message() {
      var message = 'Test timed out after ${niceDuration(timeout)}.';
      if (timeout == defaultTimeout) {
        message += ' See https://pub.dev/packages/test#timeouts';
      }
      return message;
    }

    _timeoutTimer = Zone.root.createTimer(timeout, () {
      var targetZone = _outstandingCallbackZones.isNotEmpty
          ? _outstandingCallbackZones.last
          : (_mainExecutionZone ?? Zone.root);

      targetZone.run(() {
        _handleError(Zone.current, TimeoutException(message(), timeout));

        var robustCompleter = _currentRobustCompleter;
        if (robustCompleter != null && !robustCompleter.isCompleted) {
          robustCompleter.complete(false);
        }

        _outstandingCallbacks.complete();
      });
    });
  }

  /// Marks the current test as skipped.
  ///
  /// If passed, [message] is emitted as a skip message.
  ///
  /// Note that this *does not* mark the test as complete. That is, it sets
  /// the result to [Result.skipped], but doesn't change the state.
  void skip([String? message]) {
    if (liveTest.state.shouldBeDone) {
      // Set the state explicitly so we don't get an extra error about the test
      // failing after being complete.
      _controller.setState(const State(Status.complete, Result.error));
      throw 'This test was marked as skipped after it had already completed.\n'
          'Make sure to use a matching library which informs the test runner\n'
          'of pending async work.';
    }

    if (message != null) _controller.message(Message.skip(message));
    // TODO: error if the test is already complete.
    _controller.setState(const State(Status.pending, Result.skipped));
  }

  /// Prints [message] if and when this test fails.
  void printOnFailure(String message) {
    message = message.trim();
    if (liveTest.state.result.isFailing) {
      _print('\n$message');
    } else {
      _printsOnFailure.add(message);
    }
  }

  /// Notifies the invoker of an asynchronous error.
  ///
  /// The [zone] is the zone in which the error was thrown.
  void _handleError(Zone zone, Object error, [StackTrace? stackTrace]) {
    // Ignore errors propagated from previous test runs
    if (_runCount != zone[#runCount]) return;

    // Get the chain information from the zone in which the error was thrown.
    zone.run(() {
      if (stackTrace == null) {
        stackTrace = Chain.current();
      } else {
        stackTrace = Chain.forTrace(stackTrace!);
      }
    });

    // Store these here because they'll change when we set the state below.
    var shouldBeDone = liveTest.state.shouldBeDone;

    if (error is! TestFailure) {
      _controller.setState(const State(Status.complete, Result.error));
    } else if (liveTest.state.result != Result.error) {
      _controller.setState(const State(Status.complete, Result.failure));
    }

    _controller.addError(error, stackTrace!);

    if (_printsOnFailure.isNotEmpty) {
      _print(_printsOnFailure.join('\n\n'));
      _printsOnFailure.clear();
    }

    // If a test was supposed to be done but then had an error, that indicates
    // that it was poorly-written and could be flaky.
    if (!shouldBeDone) return;

    // However, users don't think of load tests as "tests", so the error isn't
    // helpful for them.
    if (liveTest.suite.isLoadSuite) return;

    _handleError(
      zone,
      'This test failed after it had already completed.\n'
      'Make sure to use a matching library which informs the test runner\n'
      'of pending async work.',
      stackTrace,
    );
  }

  /// The method that's run when the test is started.
  void _onRun() {
    _controller.setState(const State(Status.running, Result.success));

    _runCount++;
    Chain.capture(
      () {
        _guardIfGuarded(() {
          runZoned(
            () async {
              _mainExecutionZone = Zone.current;
              // Run the test asynchronously so that the "running" state change
              // has a chance to hit its event handler(s) before the test produces
              // an error. If an error is emitted before the first state change is
              // handled, we can end up with [onError] callbacks firing before the
              // corresponding [onStateChange], which violates the timing
              // guarantees.
              //
              // Use the event loop over the microtask queue to avoid starvation.
              await Future(() {});

              await _waitForOutstandingCallbacks(_test._body);
              await _waitForOutstandingCallbacks(
                () => runTearDowns(_tearDowns),
              );

              if (_timeoutTimer != null) _timeoutTimer!.cancel();

              if (liveTest.state.result != Result.success &&
                  _runCount < liveTest.test.metadata.retry + 1) {
                _controller.message(
                  Message.print('Retry: ${liveTest.test.name}'),
                );
                _onRun();
                return;
              }

              _controller.setState(
                State(Status.complete, liveTest.state.result),
              );

              _controller.completer.complete();
            },
            zoneValues: {#test.invoker: this, #runCount: _runCount},
            zoneSpecification: ZoneSpecification(
              print: (_, _, _, line) => _print(line),
            ),
          );
        });
      },

      when: liveTest.test.metadata.chainStackTraces,
      errorZone: false,
    );
  }

  /// Runs [callback], in a [Invoker.guard] context if [_guarded] is `true`.
  void _guardIfGuarded(void Function() callback) {
    if (_guarded) {
      Invoker.guard(callback);
    } else {
      callback();
    }
  }

  /// Prints [text] as a message to [_controller].
  void _print(String text) => _controller.message(Message.print(text));

  /// Runs [fn] robustly in [zone], guaranteed to complete the returned [Future]
  /// with `true` on success, or `false` on sync/async error, deadlocks, or timeouts.
  Future<bool> runRobustly(
    Zone baseZone,
    FutureOr<dynamic> Function() fn, {
    Map<Object?, Object?>? values,
    bool completeOnAsyncError = true,
  }) {
    Zone targetZoneToFork;
    if (baseZone[#test.managedErrorZone] == true) {
      targetZoneToFork = baseZone;
    } else {
      var errorZone = _errorZone;
      if (errorZone == null || !identical(errorZone.parent, baseZone)) {
        errorZone = baseZone.fork(
          specification: _cachedZoneSpecification,
          zoneValues: {#test.managedErrorZone: true},
        );
        _errorZone = errorZone;
      }
      targetZoneToFork = errorZone!;
    }

    var completer = Completer<bool>();
    var oldCompleter = _currentRobustCompleter;
    _currentRobustCompleter = completer;
    var oldCompleteOnAsyncError = _completeOnAsyncError;
    _completeOnAsyncError = completeOnAsyncError;

    runInZone(
      targetZoneToFork,
      () {
        try {
          var result = fn();
          if (result is Future) {
            result.then(
              (_) {
                if (!completer.isCompleted) completer.complete(true);
              },
              onError: (error, stackTrace) {
                _handleError(Zone.current, error, stackTrace);
                if (!completer.isCompleted) completer.complete(false);
              },
            );
          } else {
            if (!completer.isCompleted) completer.complete(true);
          }
        } catch (error, stackTrace) {
          _handleError(Zone.current, error, stackTrace);
          if (!completer.isCompleted) completer.complete(false);
        }
      },
      of: Zone.current,
      values: {#test.invoker: this, #runCount: _runCount, ...?values},
    );

    return completer.future.whenComplete(() {
      _currentRobustCompleter = oldCompleter;
      _completeOnAsyncError = oldCompleteOnAsyncError;
    });
  }
}

/// A manually incremented/decremented counter that completes a [Future] the
/// first time it reaches zero or is forcefully completed.
class _AsyncCounter {
  var _count = 1;

  /// A Future that completes the first time the counter reaches 0.
  Future<void> get onZero => _completer.future;
  final _completer = Completer<void>();

  void increment() {
    _count++;
  }

  void decrement() {
    _count--;
    if (_count != 0) return;
    if (_completer.isCompleted) return;
    _completer.complete();
  }

  /// Force [onZero] to complete.
  ///
  /// No effect if [onZero] has already completed.
  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

extension<T> on Future<T> {
  void get unawaited {}
}
