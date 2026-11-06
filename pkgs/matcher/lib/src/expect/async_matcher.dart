// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:test_api/hooks.dart';

import '../async_matcher_restriction.dart';
import '../description.dart';
import '../equals_matcher.dart';
import '../interfaces.dart';
import '../operator_matchers.dart';
import '../type_matcher.dart';
import 'expect.dart';

/// A matcher that does asynchronous computation.
///
/// Rather than implementing [matches], subclasses implement [matchAsync].
/// [AsyncMatcher.matches] ensures that the test doesn't complete until the
/// returned future completes, and [expect] returns a future that completes when
/// the returned future completes so that tests can wait for it.
abstract class AsyncMatcher extends Matcher {
  const AsyncMatcher();

  /// Returns `null` if this matches [item], or a [String] description of the
  /// failure if it doesn't match.
  ///
  /// This can return a [Future] or a synchronous value. If it returns a
  /// [Future], neither [expect] nor the test will complete until that [Future]
  /// completes.
  ///
  /// If this returns a [String] synchronously, [expect] will synchronously
  /// throw a [TestFailure] and [matches] will synchronously return `false`.
  dynamic /*FutureOr<String>*/ matchAsync(dynamic item);

  /// Whether this matcher may be used inside operators that only support
  /// synchronous matchers, such as `isNot` and `anyOf`, for inputs where
  /// [matchAsync] returns synchronously.
  ///
  /// When `false`, [matches] rejects any use inside those operators before
  /// calling [matchAsync]. When `true`, [matches] calls [matchAsync] and
  /// rejects the use only if it returns a [Future]. Subclasses that override
  /// this to return `true` should avoid starting asynchronous work whose
  /// result would be lost when the returned [Future] is discarded.
  bool get mayMatchSynchronously => false;

  @override
  bool matches(dynamic item, Map matchState) {
    if (!mayMatchSynchronously) checkAsyncMatcherAllowed(this);
    final result = matchAsync(item);
    expect(
      result,
      anyOf([
        equals(null),
        const TypeMatcher<Future>(),
        const TypeMatcher<String>(),
      ]),
      reason: 'matchAsync() may only return a String, a Future, or null.',
    );

    if (result is Future) {
      if (mayMatchSynchronously) {
        try {
          checkAsyncMatcherAllowed(this);
        } catch (_) {
          result.ignore();
          rethrow;
        }
      }
      final outstandingWork = TestHandle.current.markPending();
      result.then((realResult) {
        if (realResult != null) {
          fail(formatFailure(this, item, realResult as String));
        }
        outstandingWork.complete();
      });
    } else if (result is String) {
      matchState[this] = result;
      return false;
    }

    return true;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) => StringDescription(matchState[this] as String);
}
