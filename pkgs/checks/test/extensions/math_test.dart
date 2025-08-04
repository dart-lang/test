// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('num checks', () {
    group('isNaN', () {
      test('succeeds for happy case', () {
        check(double.nan).isNaN();
      });
      test('fails for ints', () {
        check(42).isRejectedBy((it) => it.isNaN(), which: ['is a number']);
      });
      test('fails for numeric doubles', () {
        check(42.1).isRejectedBy((it) => it.isNaN(), which: ['is a number']);
      });
    });

    group('isNotNan', () {
      test('succeeds for ints', () {
        check(42).isNotNaN();
      });
      test('succeeds numeric doubles', () {
        check(42.1).isNotNaN();
      });
      test('fails for NaN', () {
        check(
          double.nan,
        ).isRejectedBy((it) => it.isNotNaN(), which: ['is not a number (NaN)']);
      });
    });
    group('isNegative', () {
      test('succeeds for negative ints', () {
        check(-1).isNegative();
      });
      test('succeeds for -0.0', () {
        check(-0.0).isNegative();
      });
      test('fails for zero', () {
        check(
          0,
        ).isRejectedBy((it) => it.isNegative(), which: ['is not negative']);
      });
    });
    group('isNotNegative', () {
      test('succeeds for positive ints', () {
        check(1).isNotNegative();
      });
      test('succeeds for 0', () {
        check(0).isNotNegative();
      });
      test('fails for -0.0', () {
        check(
          -0.0,
        ).isRejectedBy((it) => it.isNotNegative(), which: ['is negative']);
      });
      test('fails for negative numbers', () {
        check(
          -1,
        ).isRejectedBy((it) => it.isNotNegative(), which: ['is negative']);
      });
    });

    group('isFinite', () {
      test('succeeds for finite numbers', () {
        check(1).isFinite();
      });
      test('fails for NaN', () {
        check(
          double.nan,
        ).isRejectedBy((it) => it.isFinite(), which: ['is not finite']);
      });
      test('fails for infinity', () {
        check(
          double.infinity,
        ).isRejectedBy((it) => it.isFinite(), which: ['is not finite']);
      });
      test('fails for negative infinity', () {
        check(
          double.negativeInfinity,
        ).isRejectedBy((it) => it.isFinite(), which: ['is not finite']);
      });
    });
    group('isNotFinite', () {
      test('succeeds for infinity', () {
        check(double.infinity).isNotFinite();
      });
      test('succeeds for negative infinity', () {
        check(double.negativeInfinity).isNotFinite();
      });
      test('succeeds for NaN', () {
        check(double.nan).isNotFinite();
      });
      test('fails for finite numbers', () {
        check(1).isRejectedBy((it) => it.isNotFinite(), which: ['is finite']);
      });
    });
    group('isInfinite', () {
      test('succeeds for infinity', () {
        check(double.infinity).isInfinite();
      });
      test('succeeds for negative infinity', () {
        check(double.negativeInfinity).isInfinite();
      });
      test('fails for NaN', () {
        check(
          double.nan,
        ).isRejectedBy((it) => it.isInfinite(), which: ['is not infinite']);
      });
      test('fails for finite numbers', () {
        check(
          1,
        ).isRejectedBy((it) => it.isInfinite(), which: ['is not infinite']);
      });
    });

    group('isNotInfinite', () {
      test('succeeds for finite numbers', () {
        check(1).isNotInfinite();
      });
      test('succeeds for NaN', () {
        check(double.nan).isNotInfinite();
      });
      test('fails for infinity', () {
        check(
          double.infinity,
        ).isRejectedBy((it) => it.isNotInfinite(), which: ['is infinite']);
      });
      test('fails for negative infinity', () {
        check(
          double.negativeInfinity,
        ).isRejectedBy((it) => it.isNotInfinite(), which: ['is infinite']);
      });
    });
    group('closeTo', () {
      test('succeeds for equal numbers', () {
        check(1).isCloseTo(1, 1);
      });
      test('succeeds at less than delta away', () {
        check(1).isCloseTo(2, 2);
      });
      test('succeeds at exactly delta away', () {
        check(1).isCloseTo(2, 1);
      });
      test('fails for low values', () {
        check(
          1,
        ).isRejectedBy((it) => it.isCloseTo(3, 1), which: ['differs by <2>']);
      });
      test('fails for high values', () {
        check(
          5,
        ).isRejectedBy((it) => it.isCloseTo(3, 1), which: ['differs by <2>']);
      });
    });
  });
}
