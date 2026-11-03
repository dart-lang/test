// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('closeTo', () {
    shouldPass(0, closeTo(0, 1));
    shouldPass(-1, closeTo(0, 1));
    shouldPass(1, closeTo(0, 1));
    shouldFail(
      1.001,
      closeTo(0, 1),
      'Expected: a numeric value within <1> of <0> '
      'Actual: <1.001> '
      'Which: differs by <1.001>',
    );
    shouldFail(
      -1.001,
      closeTo(0, 1),
      'Expected: a numeric value within <1> of <0> '
      'Actual: <-1.001> '
      'Which: differs by <1.001>',
    );
    shouldFail(
      'not a num',
      closeTo(0, 1),
      endsWith('not an <Instance of \'num\'>'),
    );
  });

  test('closeTo with integer limits', () {
    var min = int.parse('-9223372036854775808');
    var max = int.parse('9223372036854775807');
    shouldFail(
      min,
      closeTo(0, 0),
      endsWith('differs by <9223372036854775808>'),
    );
    shouldFail(
      max,
      closeTo(min, max),
      endsWith('differs by <18446744073709551615>'),
    );
    shouldFail(
      min,
      closeTo(max, max),
      endsWith('differs by <18446744073709551615>'),
    );
    shouldPass(max, closeTo(0, max));
    shouldFail(
      min,
      closeTo(0, max),
      endsWith('differs by <9223372036854775808>'),
    );
    shouldPass(min, closeTo(0, 9223372036854775808.0));
    shouldPass(max - 1, closeTo(max, 1));
    shouldPass(min + 1, closeTo(min, 1));
  }, skip: identical(1, 1.0));

  test('closeTo preserves integer precision with double values', () {
    var large = int.parse('9007199254740993');
    shouldFail(
      large,
      closeTo(0, 9007199254740992.0),
      endsWith('differs by <9007199254740993>'),
    );
    shouldFail(
      large,
      closeTo(9007199254740992.0, 0),
      endsWith('differs by <1>'),
    );
    shouldFail(
      9007199254740992.0,
      closeTo(large, 0),
      endsWith('differs by <1>'),
    );
    shouldPass(large, closeTo(9007199254740992.0, 1));
  }, skip: identical(1, 1.0));

  test(
    'closeTo preserves distances beyond double precision on all platforms',
    () {
      const large = 9007199254740992;
      shouldFail(
        -1,
        closeTo(large, large),
        endsWith('differs by <9007199254740993>'),
      );
      shouldFail(
        large,
        closeTo(-1, large),
        endsWith('differs by <9007199254740993>'),
      );
      shouldPass(0, closeTo(large, large));
    },
  );

  test('closeTo with non-finite numbers and negative deltas', () {
    for (var value in [
      0,
      0.0,
      double.infinity,
      double.negativeInfinity,
      double.nan,
    ]) {
      expect(closeTo(value, double.nan).matches(value, {}), isFalse);
      expect(closeTo(value, -1).matches(value, {}), isFalse);
      expect(
        closeTo(value, double.negativeInfinity).matches(value, {}),
        isFalse,
      );
      expect(closeTo(value, double.infinity).matches(double.nan, {}), isFalse);
    }
    shouldPass(1, closeTo(0, double.infinity));
    shouldPass(double.infinity, closeTo(0, double.infinity));
    shouldPass(0, closeTo(double.infinity, double.infinity));
    expect(
      closeTo(double.infinity, double.infinity).matches(double.infinity, {}),
      isFalse,
    );
    expect(closeTo(0, 1).matches(double.infinity, {}), isFalse);
    shouldPass(1.25, closeTo(1, 0.25));
    shouldPass(1, closeTo(1.25, 0.25));
    shouldPass(1, closeTo(1, 0.5));
    expect(closeTo(1, 0.5).matches(2, {}), isFalse);
  });

  test('inInclusiveRange', () {
    shouldFail(
      -1,
      inInclusiveRange(0, 2),
      'Expected: be in range from 0 (inclusive) to 2 (inclusive) '
      'Actual: <-1>',
    );
    shouldPass(0, inInclusiveRange(0, 2));
    shouldPass(1, inInclusiveRange(0, 2));
    shouldPass(2, inInclusiveRange(0, 2));
    shouldFail(
      3,
      inInclusiveRange(0, 2),
      'Expected: be in range from 0 (inclusive) to 2 (inclusive) '
      'Actual: <3>',
    );
    shouldFail(
      'not a num',
      inInclusiveRange(0, 1),
      endsWith('not an <Instance of \'num\'>'),
    );
  });

  test('inExclusiveRange', () {
    shouldFail(
      0,
      inExclusiveRange(0, 2),
      'Expected: be in range from 0 (exclusive) to 2 (exclusive) '
      'Actual: <0>',
    );
    shouldPass(1, inExclusiveRange(0, 2));
    shouldFail(
      2,
      inExclusiveRange(0, 2),
      'Expected: be in range from 0 (exclusive) to 2 (exclusive) '
      'Actual: <2>',
    );
    shouldFail(
      'not a num',
      inExclusiveRange(0, 1),
      endsWith('not an <Instance of \'num\'>'),
    );
  });

  test('inOpenClosedRange', () {
    shouldFail(
      0,
      inOpenClosedRange(0, 2),
      'Expected: be in range from 0 (exclusive) to 2 (inclusive) '
      'Actual: <0>',
    );
    shouldPass(1, inOpenClosedRange(0, 2));
    shouldPass(2, inOpenClosedRange(0, 2));
    shouldFail(
      'not a num',
      inOpenClosedRange(0, 1),
      endsWith('not an <Instance of \'num\'>'),
    );
  });

  test('inClosedOpenRange', () {
    shouldPass(0, inClosedOpenRange(0, 2));
    shouldPass(1, inClosedOpenRange(0, 2));
    shouldFail(
      2,
      inClosedOpenRange(0, 2),
      'Expected: be in range from 0 (inclusive) to 2 (exclusive) '
      'Actual: <2>',
    );
    shouldFail(
      'not a num',
      inClosedOpenRange(0, 1),
      endsWith('not an <Instance of \'num\'>'),
    );
  });

  group('NaN', () {
    test('inInclusiveRange', () {
      shouldFail(
        double.nan,
        inExclusiveRange(double.negativeInfinity, double.infinity),
        'Expected: be in range from '
        '-Infinity (exclusive) to Infinity (exclusive) '
        'Actual: <NaN>',
      );
    });
  });
}
