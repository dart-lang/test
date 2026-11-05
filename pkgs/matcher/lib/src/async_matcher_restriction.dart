// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'description.dart';
import 'interfaces.dart';

/// Zone key holding the name of an operator (such as `isNot`) whose operands
/// are being matched, or `null` outside of such operators.
///
/// Asynchronous matchers report a pending result as a synchronous match and
/// fail the test later, so operators that inspect the synchronous result of
/// their operands cannot combine them correctly. These operators run their
/// operands with this key set so asynchronous matchers can reject the usage.
const _restrictingOperatorKey = #matcher.asyncMatcherRestrictingOperator;

/// Runs [body] in a context where asynchronous matchers are rejected because
/// their results would be consumed by [operator].
///
/// If already in a restricted context, [body] runs in that context.
T restrictAsyncMatchers<T>(String operator, T Function() body) {
  if (Zone.current[_restrictingOperatorKey] != null) return body();
  return runZoned(body, zoneValues: {_restrictingOperatorKey: operator});
}

/// Runs [body] in a context where asynchronous matchers are allowed.
///
/// Used by `expect` so that expectations made in code that runs while an
/// operator is matching (for instance inside a `predicate` callback) are
/// independent of that operator.
T allowAsyncMatchers<T>(T Function() body) {
  if (Zone.current[_restrictingOperatorKey] == null) return body();
  return runZoned(body, zoneValues: {_restrictingOperatorKey: null});
}

/// Throws an [ArgumentError] if [matcher], which matches asynchronously, is
/// being used as an operand of an operator that only supports synchronous
/// matchers.
void checkAsyncMatcherAllowed(Matcher matcher) {
  final operator = Zone.current[_restrictingOperatorKey] as String?;
  if (operator == null) return;
  final description = StringDescription().addDescriptionOf(matcher);
  throw ArgumentError(
    '$operator cannot be used with asynchronous matchers, '
    'but was used with "$description".',
  );
}
