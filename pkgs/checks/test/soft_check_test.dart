// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import 'test_shared.dart';

void main() {
  group('softCheck', () {
    test('returns the first failure', () {
      check(0).isRejectedBy(
        .it()
          ..isGreaterThan(1)
          ..isGreaterThan(2),
        which: ['is not greater than <1>'],
      );
    });

    test('describes a rejected guard followed by nested clauses', () {
      final failure = (Condition.it<Object?>()..isA<String>().length.equals(1))
          .softCheckSync(1);
      check(failure).isNotNull()
        ..has(
          (f) => f.rejection.which,
          'which',
        ).isNotNull().deepEquals(['is a int'])
        ..has((f) => f.detail, 'detail')
            .has((d) => d.expected, 'expected')
            .deepEquals([' that:', '  is a String', '  has length: <1>']);
    });
  });
  group('softCheckAsync', () {
    test('returns the first failure', () async {
      await check(Future.value(0)).isRejectedByAsync(
        .it()
          ..completes(.it()..isGreaterThan(1))
          ..completes(.it()..isGreaterThan(2)),
        actual: ['<0>'],
        which: ['is not greater than <1>'],
      );
    });
  });
  group('CheckFailure.describeNested', () {
    Iterable<String> describeNested<T>(Condition<T> condition, T value) =>
        condition.softCheckSync(value)!.describeNested();

    test('uses the collapsed actual for a single expectation', () {
      check(
        describeNested(Condition.it<int>()..isLessThan(0), 1),
      ).deepEquals(['Actual: <1>', 'Which: is not less than <0>']);
    });

    test('uses the collapsed actual for a nested subject', () {
      check(
        describeNested(Condition.it<String>()..length.equals(2), 'abc'),
      ).deepEquals(['Actual: has length: <3>', 'Which: is not equal']);
    });

    test('uses an actual collapsed to the root', () {
      check(
        describeNested(
          Condition.it<String>()
            ..length.which(
              .it()
                ..isGreaterThan(0)
                ..isLessThan(2),
            ),
          'abc',
        ),
      ).deepEquals(['Actual: has length: <3>', 'Which: is not less than <2>']);
    });

    test('omits the root label line from a custom actual', () {
      check(
        describeNested(
          Condition.it<String>()
            ..startsWith('a')
            ..length.equals(2),
          'abc',
        ),
      ).deepEquals([
        "  starts with 'a'",
        '  has length: <3>',
        '  Which: is not equal',
      ]);
    });

    test('omits the root label line before the rejected actual', () {
      check(
        describeNested(
          Condition.it<String>()
            ..context
                .nest<int>(
                  () => ['has a derived length'],
                  (s) => Extracted.value(s.length),
                )
                .which(
                  .it()
                    ..isGreaterThan(0)
                    ..isLessThan(2),
                ),
          'abc',
        ),
      ).deepEquals([
        '  has a derived length that:',
        '  Actual: <3>',
        '  Which: is not less than <2>',
      ]);
    });
  });
}
