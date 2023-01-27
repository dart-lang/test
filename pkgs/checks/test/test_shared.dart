// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';

extension RejectionChecks<T> on Check<T> {
  void isRejectedBy(Condition<T> condition,
      {Iterable<String>? actual, Iterable<String>? which}) {
    late T actualValue;
    var didRunCallback = false;
    final rejection = context
        .nest<Rejection>('does not meet a condition with a Rejection', (value) {
      actualValue = value;
      didRunCallback = true;
      final failure = softCheck(value, condition);
      if (failure == null) {
        return Extracted.rejection(which: [
          'was accepted by the condition checking:',
          ...describe(condition)
        ]);
      }
      return Extracted.value(failure.rejection);
    });
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

  Future<void> isRejectedByAsync(Condition<T> condition,
      {Iterable<String>? actual, Iterable<String>? which}) async {
    late T actualValue;
    var didRunCallback = false;
    final rejection = (await context.nestAsync<Rejection>(
        'does not meet an async condition with a Rejection', (value) async {
      actualValue = value;
      didRunCallback = true;
      final failure = await softCheckAsync(value, condition);
      if (failure == null) {
        return Extracted.rejection(which: [
          'was accepted by the condition checking:',
          ...await describeAsync(condition)
        ]);
      }
      return Extracted.value(failure.rejection);
    }));
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

extension ConditionChecks<T> on Check<Condition<T>> {
  Check<Iterable<String>> get description =>
      has((c) => describe<T>(c), 'description');
  Future<Check<Iterable<String>>> get asyncDescription async =>
      context.nestAsync(
          'has description',
          (condition) async =>
              Extracted.value(await describeAsync<T>(condition)));
}
