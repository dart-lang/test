// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.engine;

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart' hide Result;
import 'package:collection/collection.dart';
import 'package:pool/pool.dart';

import '../backend/live_test.dart';
import '../backend/live_test_controller.dart';
import '../backend/state.dart';
import '../backend/suite.dart';
import '../backend/test.dart';
import '../util/delegating_sink.dart';

/// An [Engine] manages a run that encompasses multiple test suites.
///
/// The current status of every test is visible via [liveTests]. [onTestStarted]
/// can also be used to be notified when a test is about to be run.
///
/// Suites will be run in the order they're provided to [new Engine]. Tests
/// within those suites will likewise be run in the order of [Suite.tests].
class Engine {
  /// Whether [run] has been called yet.
  var _runCalled = false;

  /// Whether [close] has been called.
  var _closed = false;

  /// Whether [close] was called before all the tests finished running.
  ///
  /// This is `null` if close hasn't been called and the tests are still
  /// running, `true` if close was called before the tests finished running, and
  /// `false` if the tests finished running before close was called.
  var _closedBeforeDone;

  /// A pool that limits the number of test suites running concurrently.
  final Pool _pool;

  /// Whether all tests passed.
  ///
  /// This fires once all tests have completed and [suiteSink] has been closed.
  /// This will be `null` if [close] was called before all the tests finished
  /// running.
  Future<bool> get success async {
    await _group.future;
    if (_closedBeforeDone) return null;
    return liveTests.every((liveTest) =>
        liveTest.state.result == Result.success);
  }

  /// A group of futures for each test suite.
  final _group = new FutureGroup();

  /// A sink used to pass [Suite]s in to the engine to run.
  ///
  /// Suites may be added as quickly as they're available; the Engine will only
  /// run as many as necessary at a time based on its concurrency settings.
  Sink<Suite> get suiteSink => new DelegatingSink(_suiteController.sink);
  final _suiteController = new StreamController<Suite>();

  /// All the currently-known tests that have run, are running, or will run.
  ///
  /// These are [LiveTest]s, representing the in-progress state of each test.
  /// Tests that have not yet begun running are marked [Status.pending]; tests
  /// that have finished are marked [Status.complete].
  ///
  /// This is guaranteed to contain the same tests as the union of [passed],
  /// [skipped], [failed], and [active].
  ///
  /// [LiveTest.run] must not be called on these tests.
  List<LiveTest> get liveTests => new UnmodifiableListView(_liveTests);
  final _liveTests = new List<LiveTest>();

  /// A stream that emits each [LiveTest] as it's about to start running.
  ///
  /// This is guaranteed to fire before [LiveTest.onStateChange] first fires.
  Stream<LiveTest> get onTestStarted => _onTestStartedController.stream;
  final _onTestStartedController = new StreamController<LiveTest>.broadcast();

  /// The set of tests that have completed and been marked as passing.
  Set<LiveTest> get passed => new UnmodifiableSetView(_passed);
  final _passed = new Set<LiveTest>();

  /// The set of tests that have completed and been marked as skipped.
  Set<LiveTest> get skipped => new UnmodifiableSetView(_skipped);
  final _skipped = new Set<LiveTest>();

  /// The set of tests that have completed and been marked as failing or error.
  Set<LiveTest> get failed => new UnmodifiableSetView(_failed);
  final _failed = new Set<LiveTest>();

  /// The tests that are still running, in the order they begain running.
  List<LiveTest> get active => new UnmodifiableListView(_active);
  final _active = new List<LiveTest>();

  /// Creates an [Engine] that will run all tests provided via [suiteSink].
  ///
  /// [concurrency] controls how many suites are run at once.
  Engine({int concurrency})
      : _pool = new Pool(concurrency == null ? 1 : concurrency) {
    _group.future.then((_) {
      if (_closedBeforeDone == null) _closedBeforeDone = false;
    }).catchError((_) {
      // Don't top-level errors. They'll be thrown via [success] anyway.
    });
  }

  /// Creates an [Engine] that will run all tests in [suites].
  ///
  /// [concurrency] controls how many suites are run at once. An engine
  /// constructed this way will automatically close its [suiteSink], meaning
  /// that no further suites may be provided.
  factory Engine.withSuites(List<Suite> suites, {int concurrency}) {
    var engine = new Engine(concurrency: concurrency);
    for (var suite in suites) engine.suiteSink.add(suite);
    engine.suiteSink.close();
    return engine;
  }

  /// Runs all tests in all suites defined by this engine.
  ///
  /// This returns `true` if all tests succeed, and `false` otherwise. It will
  /// only return once all tests have finished running and [suiteSink] has been
  /// closed.
  Future<bool> run() {
    if (_runCalled) {
      throw new StateError("Engine.run() may not be called more than once.");
    }
    _runCalled = true;

    _suiteController.stream.listen((suite) {
      _group.add(_pool.withResource(() {
        if (_closed) return null;

        // TODO(nweiz): Use a real for loop when issue 23394 is fixed.
        return Future.forEach(suite.tests, (test) async {
          if (_closed) return;

          var liveTest = test.metadata.skip
              ? _skippedTest(suite, test)
              : test.load(suite);
          _liveTests.add(liveTest);
          _active.add(liveTest);

          liveTest.onStateChange.listen((state) {
            if (state.status != Status.complete) return;
            _active.remove(liveTest);

            if (state.result != Result.success) {
              _passed.remove(liveTest);
              _failed.add(liveTest);
            } else if (liveTest.test.metadata.skip) {
              _skipped.add(liveTest);
            } else {
              _passed.add(liveTest);
            }
          });

          _onTestStartedController.add(liveTest);

          // First, schedule a microtask to ensure that [onTestStarted] fires
          // before the first [LiveTest.onStateChange] event. Once the test
          // finishes, use [new Future] to do a coarse-grained event loop pump
          // to avoid starving non-microtask events.
          await new Future.microtask(liveTest.run);
          await new Future(() {});
        });
      }));
    }, onDone: _group.close);

    return success;
  }

  /// Returns a dummy [LiveTest] for a test marked as "skip".
  LiveTest _skippedTest(Suite suite, Test test) {
    var controller;
    controller = new LiveTestController(suite, test, () {
      controller.setState(const State(Status.running, Result.success));
      controller.setState(const State(Status.complete, Result.success));
      controller.completer.complete();
    }, () {});
    return controller.liveTest;
  }

  /// Signals that the caller is done paying attention to test results and the
  /// engine should release any resources it has allocated.
  ///
  /// Any actively-running tests are also closed. VM tests are allowed to finish
  /// running so that any modifications they've made to the filesystem can be
  /// cleaned up.
  ///
  /// **Note that closing the engine is not the same as closing [suiteSink].**
  /// Closing [suiteSink] indicates that no more input will be provided, closing
  /// the engine indicates that no more output should be emitted.
  Future close() {
    _closed = true;
    if (_closedBeforeDone == null) _closedBeforeDone = true;
    _suiteController.close();

    return Future.wait(liveTests.map((liveTest) => liveTest.close()));
  }
}
