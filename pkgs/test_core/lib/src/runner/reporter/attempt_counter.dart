// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test_api/backend.dart';

/// Tracks how many times each [LiveTest] has started running.
///
/// A test that is configured with `retry` is run again within the same
/// [LiveTest] after a failed attempt. Each attempt moves the test's state back
/// to [Status.running], so counting those transitions gives the attempt number.
///
/// This must not import `dart:io`, because it's used by reporters that are
/// available when test files are run directly.
final class AttemptCounter {
  final _attempts = <LiveTest, int>{};

  /// Tests whose final attempt has finished.
  final _finished = <LiveTest>{};

  /// Starts tracking attempts for [liveTest].
  ///
  /// This must be called before [liveTest] starts running, for example from a
  /// listener on `Engine.onTestStarted`. The returned subscription should be
  /// canceled along with the reporter's other subscriptions.
  StreamSubscription<State> watch(LiveTest liveTest) {
    liveTest.onComplete.then((_) => _finished.add(liveTest));
    var previous = liveTest.state.status;
    return liveTest.onStateChange.listen((state) {
      if (state.status == Status.running && previous != Status.running) {
        _attempts[liveTest] = (_attempts[liveTest] ?? 0) + 1;
      }
      previous = state.status;
    });
  }

  /// The number of attempts of [liveTest] that have started so far.
  int attemptsFor(LiveTest liveTest) => _attempts[liveTest] ?? 0;

  /// A description of the current attempt of [liveTest], such as
  /// ` (attempt 1 of 2)`, or the empty string if [liveTest] isn't retried.
  ///
  /// Load tests are retried by the loader rather than by running the same
  /// [LiveTest] again, so they never get a description. Neither do errors that
  /// arrive after the final attempt has finished, since no further attempt
  /// will follow.
  String describe(LiveTest liveTest) {
    if (liveTest.suite.isLoadSuite) return '';
    if (_finished.contains(liveTest)) return '';
    var retry = liveTest.test.metadata.retry;
    if (retry == 0) return '';
    var attempt = attemptsFor(liveTest);
    if (attempt == 0) return '';
    return ' (attempt $attempt of ${retry + 1})';
  }
}
