// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('num checks', () {
    group('greater than', () {
      test('succeeds for happy case', () {
        checkThat(42) > 7;
      });
      test('fails for less than', () {
        checkThat(softCheck<int>(42, (p0) => p0 > 50))
            .isARejection(actual: '<42>', which: ['is not greater than <50>']);
      });
      test('fails for equal', () {
        checkThat(softCheck<int>(42, (p0) => p0 > 42))
            .isARejection(actual: '<42>', which: ['is not greater than <42>']);
      });
    });

    group('greater than or equal', () {
      test('succeeds for happy case', () {
        checkThat(42) >= 7;
      });
      test('fails for less than', () {
        checkThat(softCheck<int>(42, (p0) => p0 >= 50)).isARejection(
            actual: '<42>', which: ['is not greater than or equal to <50>']);
      });
      test('succeeds for equal', () {
        checkThat(42) >= 42;
      });
    });

    group('less than', () {
      test('succeeds for happy case', () {
        checkThat(42) < 50;
      });
      test('fails for greater than', () {
        checkThat(softCheck<int>(42, (p0) => p0 < 7))
            .isARejection(actual: '<42>', which: ['is not less than <7>']);
      });
      test('fails for equal', () {
        checkThat(softCheck<int>(42, (p0) => p0 < 42))
            .isARejection(actual: '<42>', which: ['is not less than <42>']);
      });
    });

    group('less than or equal', () {
      test('succeeds for happy case', () {
        checkThat(42) <= 50;
      });
      test('fails for less than', () {
        checkThat(softCheck<int>(42, (p0) => p0 <= 7)).isARejection(
            actual: '<42>', which: ['is not less than or equal to <7>']);
      });
      test('succeeds for equal', () {
        checkThat(42) <= 42;
      });
    });

    group('isNan', () {
      test('succeeds for happy case', () {
        checkThat(double.nan).isNaN();
      });
      test('fails for ints', () {
        checkThat(softCheck<num>(42, (c) => c.isNaN()))
            .isARejection(actual: '<42>', which: ['is a number']);
      });
      test('fails for numeric doubles', () {
        checkThat(softCheck<num>(42.1, (c) => c.isNaN()))
            .isARejection(actual: '<42.1>', which: ['is a number']);
      });
    });

    group('isNan', () {
      test('succeeds for ints', () {
        checkThat(42).isNotNaN();
      });
      test('succeeds numeric doubles', () {
        checkThat(42.1).isNotNaN();
      });
      test('fails for NaN', () {
        checkThat(softCheck<num>(double.nan, (c) => c.isNotNaN()))
            .isARejection(actual: '<NaN>', which: ['is not a number (NaN)']);
      });
    });

    group('isNegative', () {
      test('succeeds for negative ints', () {
        checkThat(-1).isNegative();
      });
      test('succeeds for -0.0', () {
        checkThat(-0.0).isNegative();
      });
      test('fails for zero', () {
        checkThat(softCheck<num>(0, (c) => c.isNegative()))
            .isARejection(actual: '<0>', which: ['is not negative']);
      });
    });

    group('isNotNegative', () {
      test('succeeds for positive ints', () {
        checkThat(1).isNotNegative();
      });
      test('succeeds for 0', () {
        checkThat(0).isNotNegative();
      });
      test('fails for -0.0', () {
        checkThat(softCheck<num>(-0.0, (c) => c.isNotNegative()))
            .isARejection(actual: '<-0.0>', which: ['is negative']);
      });
      test('fails for negative numbers', () {
        checkThat(softCheck<num>(-1, (c) => c.isNotNegative()))
            .isARejection(actual: '<-1>', which: ['is negative']);
      });
    });

    group('isFinite', () {
      test('succeeds for finite numbers', () {
        checkThat(1).isFinite();
      });
      test('fails for NaN', () {
        checkThat(softCheck<num>(double.nan, (c) => c.isFinite()))
            .isARejection(actual: '<NaN>', which: ['is not finite']);
      });
      test('fails for infinity', () {
        checkThat(softCheck<num>(double.infinity, (c) => c.isFinite()))
            .isARejection(actual: '<Infinity>', which: ['is not finite']);
      });
      test('fails for negative infinity', () {
        checkThat(softCheck<num>(double.negativeInfinity, (c) => c.isFinite()))
            .isARejection(actual: '<-Infinity>', which: ['is not finite']);
      });
    });

    group('isNotFinite', () {
      test('succeeds for infinity', () {
        checkThat(double.infinity).isNotFinite();
      });
      test('succeeds for negative infinity', () {
        checkThat(double.negativeInfinity).isNotFinite();
      });
      test('succeeds for NaN', () {
        checkThat(double.nan).isNotFinite();
      });
      test('fails for finite numbers', () {
        checkThat(softCheck<num>(1, (c) => c.isNotFinite()))
            .isARejection(actual: '<1>', which: ['is finite']);
      });
    });

    group('isInfinite', () {
      test('succeeds for infinity', () {
        checkThat(double.infinity).isInfinite();
      });
      test('succeeds for negative infinity', () {
        checkThat(double.negativeInfinity).isInfinite();
      });
      test('fails for NaN', () {
        checkThat(softCheck<num>(double.nan, (c) => c.isInfinite()))
            .isARejection(actual: '<NaN>', which: ['is not infinite']);
      });
      test('fails for finite numbers', () {
        checkThat(softCheck<num>(1, (c) => c.isInfinite()))
            .isARejection(actual: '<1>', which: ['is not infinite']);
      });
    });

    group('isNotInfinite', () {
      test('succeeds for finite numbers', () {
        checkThat(1).isNotInfinite();
      });
      test('succeeds for NaN', () {
        checkThat(double.nan).isNotInfinite();
      });
      test('fails for infinity', () {
        checkThat(softCheck<num>(double.infinity, (c) => c.isNotInfinite()))
            .isARejection(actual: '<Infinity>', which: ['is infinite']);
      });
      test('fails for negative infinity', () {
        checkThat(softCheck<num>(
                double.negativeInfinity, (c) => c.isNotInfinite()))
            .isARejection(actual: '<-Infinity>', which: ['is infinite']);
      });
    });

    group('closeTo', () {
      test('succeeds for equal numbers', () {
        checkThat(1).isCloseTo(1, 1);
      });
      test('succeeds at less than delta away', () {
        checkThat(1).isCloseTo(2, 2);
      });
      test('succeeds at exactly delta away', () {
        checkThat(1).isCloseTo(2, 1);
      });
      test('fails for low values', () {
        checkThat(softCheck<num>(1, (c) => c.isCloseTo(3, 1)))
            .isARejection(actual: '<1>', which: ['differs by <2>']);
      });
      test('fails for high values', () {
        checkThat(softCheck<num>(5, (c) => c.isCloseTo(3, 1)))
            .isARejection(actual: '<5>', which: ['differs by <2>']);
      });
    });
  });
}
