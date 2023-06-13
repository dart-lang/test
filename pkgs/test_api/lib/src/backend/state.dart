// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The state of a [LiveTest].
///
/// A test's state is made up of two components, its [status] and its [result].
/// The [status] represents where the test is in its process of running; the
/// [result] represents the outcome as far as its known.
class State {
  /// Where the test is in its process of running.
  final Status status;

  /// The outcome of the test, as far as it's known.
  ///
  /// Note that if [status] is [Status.pending], [result] will always be
  /// [Result.success] since the test hasn't yet had a chance to fail.
  final Result result;

  /// Whether a test in this state is expected to be done running code.
  ///
  /// If [status] is [Status.complete] and [result] doesn't indicate an error, a
  /// properly-written test case should not be running any more code. However,
  /// it may have started asynchronous processes without notifying the test
  /// runner.
  bool get shouldBeDone => status == Status.complete && result.isPassing;

  const State(this.status, this.result);

  @override
  bool operator ==(Object other) =>
      other is State && status == other.status && result == other.result;

  @override
  int get hashCode => status.hashCode ^ (7 * result.hashCode);

  @override
  String toString() {
    if (status == Status.pending) return 'pending';
    if (status == Status.complete) return result.toString();
    if (result == Result.success) return 'running';
    return 'running with $result';
  }
}

/// Where the test is in its process of running.
enum Status {
  /// The test has not yet begun running.
  pending,

  /// The test is currently running.
  running,

  /// The test has finished running.
  ///
  /// Note that even if the test is marked [complete], it may still be running
  /// code asynchronously. A test is considered complete either once it hits its
  /// first error or when all [expectAsync] callbacks have been called and any
  /// returned [Future] has completed, but it's possible for further processing
  /// to happen, which may cause further errors.
  complete;

  factory Status.parse(String name) => Status.values.byName(name);

  @override
  String toString() => name;
}

/// The outcome of the test, as far as it's known.
enum Result {
  /// The test has not yet failed in any way.
  ///
  /// Note that this doesn't mean that the test won't fail in the future.
  success,

  /// The test, or some part of it, has been skipped.
  ///
  /// This implies that the test hasn't failed *yet*. However, it this doesn't
  /// mean that the test won't fail in the future.
  skipped,

  /// The test has failed.
  ///
  /// A failure is specifically caused by a [TestFailure] being thrown; any
  /// other exception causes an error.
  failure,

  /// The test has crashed.
  ///
  /// Any exception other than a [TestFailure] is considered to be an error.
  error;

  /// Whether this is a passing result.
  ///
  /// A test is considered to have passed if it's a success or if it was
  /// skipped.
  bool get isPassing => this == success || this == skipped;

  /// Whether this is a failing result.
  ///
  /// A test is considered to have failed if it experiences a failure or an
  /// error.
  bool get isFailing => !isPassing;

  factory Result.parse(String name) => Result.values.byName(name);

  @override
  String toString() => name;
}
