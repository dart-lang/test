// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:meta/meta.dart' hide literal;

extension RejectionChecks<T> on Subject<T> {
  void isRejectedBy(
    Condition<T> condition, {
    Iterable<String>? actual,
    Iterable<String>? which,
  }) {
    late T actualValue;
    var didRunCallback = false;
    final rejection = context.nest<Rejection>(
      () => ['does not meet a condition with a Rejection'],
      (value) {
        actualValue = value;
        didRunCallback = true;
        final failure = condition.softCheckSync(value);
        if (failure == null) {
          return Extracted.rejection(
            which: [
              'was accepted by the condition checking:',
              ...condition.describeSync(),
            ],
          );
        }
        return Extracted.value(failure.rejection);
      },
    );
    if (didRunCallback) {
      rejection
          .has((r) => r.actual, 'actual')
          .deepEquals(actual ?? literal(actualValue));
    } else {
      rejection
          .has((r) => r.actual, 'actual')
          .context
          .expect(() => ['is left default'], (_) => null);
    }
    if (which == null) {
      rejection.has((r) => r.which, 'which').isNull();
    } else {
      rejection.has((r) => r.which, 'which').isNotNull().deepEquals(which);
    }
  }

  Future<void> isRejectedByAsync(
    Condition<T> condition, {
    Iterable<String>? actual,
    Iterable<String>? which,
  }) async {
    late T actualValue;
    var didRunCallback = false;
    final rejection = await context.nestAsync<Rejection>(
      () => ['does not meet an async condition with a Rejection'],
      (value) async {
        actualValue = value;
        didRunCallback = true;
        final failure = await condition.softCheck(value);
        if (failure == null) {
          return Extracted.rejection(
            which: [
              'was accepted by the condition checking:',
              ...await condition.describe(),
            ],
          );
        }
        return Extracted.value(failure.rejection);
      },
    );
    if (didRunCallback) {
      rejection
          .has((r) => r.actual, 'actual')
          .deepEquals(actual ?? literal(actualValue));
    } else {
      rejection
          .has((r) => r.actual, 'actual')
          .context
          .expect(() => ['is left default'], (_) => null);
    }
    if (which == null) {
      rejection.has((r) => r.which, 'which').isNull();
    } else {
      rejection.has((r) => r.which, 'which').isNotNull().deepEquals(which);
    }
  }
}

extension ConditionChecks<T> on Subject<Condition<T>> {
  @useResult
  Subject<Iterable<String>> hasSyncDescription() =>
      has((c) => c.describeSync(), 'description');
}

extension AsyncConditionChecks<T> on Subject<Condition<T>> {
  Future<void> hasAsyncDescriptionWhich(
    Condition<Iterable<String>> descriptionCondition,
  ) async {
    final nested = await context.nestAsync(
      () => ['has description'],
      (condition) async => Extracted.value(await condition.describe()),
    );
    nested.which(descriptionCondition);
  }
}
