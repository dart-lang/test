// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'src/backend/group.dart';
import 'src/backend/invoker.dart';
import 'src/backend/live_test.dart';
import 'src/backend/metadata.dart';
import 'src/backend/runtime.dart';
import 'src/backend/state.dart';
import 'src/backend/suite.dart';
import 'src/backend/suite_platform.dart';

export 'src/backend/state.dart' show Result, Status;
export 'src/backend/test_failure.dart' show TestFailure;

/// A monitor for the behavior of a callback when it is run as the body of a
/// test case.
///
/// Allows running a callback as the body of a local test case and querying for
/// the current [status], [result], and [errors] from the test.
///
/// Use [run] to run a test body and query for the success or failure.
///
/// Use [start] to start a test and query for whether it has finished running.
class TestCaseMonitor {
  final LiveTest _liveTest;
  final _done = Completer<void>();
  TestCaseMonitor._(FutureOr<void> Function() body)
      : _liveTest = _createTest(body);

  /// Run [body] as a test case and return a [TestCaseMonitor] with the result.
  ///
  /// The [status] of the returned result will always be [Status.complete].
  /// The [result] and [errors] will reflect the latest state of the test.
  /// {@template result-late-fail}
  /// Note that a test can change result from success to failure even after it
  /// has already completed if the test surfaces an unawaited asynchronous
  /// error.
  /// {@endtemplate}
  ///
  /// ```dart
  /// final monitor = await TestCaseMonitor.run(() {
  ///   fail('oh no!');
  /// });
  /// assert(monitor.result == Result.failure);
  /// assert((monitor.errors.single.error as TestFailure).message == 'oh no!');
  /// ```
  static Future<TestCaseMonitor> run(FutureOr<void> Function() body) async {
    final monitor = TestCaseMonitor.start(body);
    await monitor.onDone;
    return monitor;
  }

  /// Start [body] as a test case and return a [TestCaseMonitor] with the status
  /// and result.
  ///
  /// The [status] of the test will be [Status.running] until it completes.
  /// The [result] and [errors] will reflect the latest state of the test.
  /// {@macro result-late-fail}
  ///
  /// ```dart
  /// late void Function() completeWork;
  /// final monitor = TestCaseMonitor.start(() {
  ///   final outstandingWork = TestHandle.current.markPending();
  ///   completeWork = outstandingWork.complete;
  /// });
  /// await pumpEventQueue();
  /// assert(monitor.status == Status.running);
  /// completeWork();
  /// await monitor.onDone;
  /// assert(monitor.status == Status.complete);
  /// ```
  /// The [result] and [errors] will reflect the latest state of the test.
  static TestCaseMonitor start(FutureOr<void> Function() body) =>
      TestCaseMonitor._(body).._start();

  void _start() {
    _liveTest.run().whenComplete(_done.complete);
  }

  /// A future that completes after this test has finished running, or has
  /// surfaced an error.
  Future<void> get onDone => _done.future;

  /// The run status for the test.
  Status get status => _liveTest.state.status;

  /// The result for the test.
  ///
  /// A test that is still running may have a result of [Result.success] because
  /// it has not failed _yet_. The result should only be read after the test is
  /// done.
  ///
  /// {@macro result-late-fail}
  ///
  /// A failed test my be a [Result.failure] if the test failed with a
  /// [TestFailure] exception, or a [Result.error] if it failed with any other
  /// type of exception.
  Result get result => _liveTest.state.result;

  /// The errors surfaced by the test.
  ///
  /// A test with any errors will have a failing [result].
  ///
  /// {@macro result-late-fail}
  ///
  /// A test may have more than one error if there were unhandled asynchronous
  /// errors surfaced after the test is done.
  Iterable<AsyncError> get errors => _liveTest.errors;

  /// A stream of errors surfaced by the test.
  ///
  /// This stream will not close, asynchronous errors may be surfaced within the
  /// test's error zone at any point.
  Stream<AsyncError> get onError => _liveTest.onError;
}

/// Returns a local [LiveTest] that runs [body].
LiveTest _createTest(FutureOr<void> Function() body) {
  var test = LocalTest('test', Metadata(chainStackTraces: true), body);
  var suite = Suite(Group.root([test]), _suitePlatform, ignoreTimeouts: false);
  return test.load(suite);
}

/// A dummy suite platform to use for testing suites.
final _suitePlatform =
    SuitePlatform(Runtime.vm, compiler: Runtime.vm.defaultCompiler);
