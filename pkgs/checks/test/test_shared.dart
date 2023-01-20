// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:checks/src/checks.dart' show softCheckAsync, describeAsync;

extension RejectionChecks<T> on Check<T> {
  void isRejectedBy(Condition<T> condition,
      {Condition<Iterable<String>>? hasWhichThat,
      Condition<Iterable<String>>? hasActualThat}) {
    late T actualValue;
    var didRunCallback = false;
    context.nest<Rejection>('does not meet a condition with a Rejection',
        (value) {
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
    })
      ..has((r) => r.actual, 'actual').that(hasActualThat ??
          (didRunCallback
              ? (it()..deepEquals(literal(actualValue)))
              : (it()
                ..context
                    .expect(() => ['uses the default actual'], (_) => null))))
      ..has((r) => r.which, 'which').that(hasWhichThat == null
          ? (it()..isNull())
          : (it()..isNotNull().that(hasWhichThat)));
  }

  Future<void> isRejectedByAsync(Condition<T> condition,
      {Condition<Iterable<String>>? hasWhichThat,
      Condition<Iterable<String>>? hasActualThat}) async {
    late T actualValue;
    var didRunCallback = false;
    (await context.nestAsync<Rejection>(() {
      return 'does not meet an async condition with a Rejection';
    }(), (value) async {
      actualValue = value;
      didRunCallback = true;
      final failure = await softCheckAsync(value, condition);
      if (failure == null)
        return Extracted.rejection(which: [
          'was accepted by the condition checking:',
          ...await describeAsync(condition)
        ]);
      return Extracted.value(failure.rejection);
    }))
      ..has((r) => r.actual, 'actual').that(hasActualThat ??
          (didRunCallback
              ? (it()..deepEquals(literal(actualValue)))
              : (it()
                ..context
                    .expect(() => ['uses the default actual'], (_) => null))))
      ..has((r) => r.which, 'which').that(hasWhichThat == null
          ? (it()..isNull())
          : (it()..isNotNull().that(hasWhichThat)));
  }
}
