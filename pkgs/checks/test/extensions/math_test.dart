// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('num checks', () {
    group('greater than', () {
      test('succeeds for happy case', () {
        42.must.beGreaterThan(7);
      });
      test('fails for less than', () {
        42.must.beRejectedBy(would()..beGreaterThan(50),
            which: ['is not greater than <50>']);
      });
      test('fails for equal', () {
        42.must.beRejectedBy(would()..beGreaterThan(42),
            which: ['is not greater than <42>']);
      });
    });

    group('greater than or equal', () {
      test('succeeds for happy case', () {
        42.must.beGreaterOrEqual(7);
      });
      test('fails for less than', () {
        42.must.beRejectedBy(would()..beGreaterOrEqual(50),
            which: ['is not greater than or equal to <50>']);
      });
      test('succeeds for equal', () {
        42.must.beGreaterOrEqual(42);
      });
    });

    group('less than', () {
      test('succeeds for happy case', () {
        42.must.beLessThat(50);
      });
      test('fails for greater than', () {
        42.must.beRejectedBy(would()..beLessThat(7),
            which: ['is not less than <7>']);
      });
      test('fails for equal', () {
        42.must.beRejectedBy(would()..beLessThat(42),
            which: ['is not less than <42>']);
      });
    });

    group('less than or equal', () {
      test('succeeds for happy case', () {
        42.must.beLessOrEqual(50);
      });
      test('fails for greater than', () {
        42.must.beRejectedBy(would()..beLessOrEqual(7),
            which: ['is not less than or equal to <7>']);
      });
      test('succeeds for equal', () {
        42.must.beLessOrEqual(42);
      });
    });

    group('isNaN', () {
      test('succeeds for happy case', () {
        (double.nan).must.beNaN();
      });
      test('fails for ints', () {
        42.must.beRejectedBy(would()..beNaN(), which: ['is a number']);
      });
      test('fails for numeric doubles', () {
        42.1.must.beRejectedBy(would()..beNaN(), which: ['is a number']);
      });
    });

    group('isNotNan', () {
      test('succeeds for ints', () {
        42.must.beANumber();
      });
      test('succeeds numeric doubles', () {
        42.1.must.beANumber();
      });
      test('fails for NaN', () {
        (double.nan).must.beRejectedBy(would()..beANumber(),
            which: ['is not a number (NaN)']);
      });
    });
    group('isNegative', () {
      test('succeeds for negative ints', () {
        (-1).must.beNegative();
      });
      test('succeeds for -0.0', () {
        (-0.0).must.beNegative();
      });
      test('fails for zero', () {
        0.must.beRejectedBy(would()..beNegative(), which: ['is not negative']);
      });
    });
    group('isNotNegative', () {
      test('succeeds for positive ints', () {
        1.must.beNonNegative();
      });
      test('succeeds for 0', () {
        0.must.beNonNegative();
      });
      test('fails for -0.0', () {
        (-0.0)
            .must
            .beRejectedBy(would()..beNonNegative(), which: ['is negative']);
      });
      test('fails for negative numbers', () {
        (-1)
            .must
            .beRejectedBy(would()..beNonNegative(), which: ['is negative']);
      });
    });

    group('isFinite', () {
      test('succeeds for finite numbers', () {
        1.must.beFinite();
      });
      test('fails for NaN', () {
        (double.nan)
            .must
            .beRejectedBy(would()..beFinite(), which: ['is not finite']);
      });
      test('fails for infinity', () {
        (double.infinity)
            .must
            .beRejectedBy(would()..beFinite(), which: ['is not finite']);
      });
      test('fails for negative infinity', () {
        (double.negativeInfinity)
            .must
            .beRejectedBy(would()..beFinite(), which: ['is not finite']);
      });
    });
    group('isNotFinite', () {
      test('succeeds for infinity', () {
        (double.infinity).must.notBeFinite();
      });
      test('succeeds for negative infinity', () {
        (double.negativeInfinity).must.notBeFinite();
      });
      test('succeeds for NaN', () {
        (double.nan).must.notBeFinite();
      });
      test('fails for finite numbers', () {
        1.must.beRejectedBy(would()..notBeFinite(), which: ['is finite']);
      });
    });
    group('isInfinite', () {
      test('succeeds for infinity', () {
        (double.infinity).must.beInfinite();
      });
      test('succeeds for negative infinity', () {
        (double.negativeInfinity).must.beInfinite();
      });
      test('fails for NaN', () {
        (double.nan)
            .must
            .beRejectedBy(would()..beInfinite(), which: ['is not infinite']);
      });
      test('fails for finite numbers', () {
        1.must.beRejectedBy(would()..beInfinite(), which: ['is not infinite']);
      });
    });

    group('isNotInfinite', () {
      test('succeeds for finite numbers', () {
        1.must.notBeInfinite();
      });
      test('succeeds for NaN', () {
        (double.nan).must.notBeInfinite();
      });
      test('fails for infinity', () {
        (double.infinity)
            .must
            .beRejectedBy(would()..notBeInfinite(), which: ['is infinite']);
      });
      test('fails for negative infinity', () {
        (double.negativeInfinity)
            .must
            .beRejectedBy(would()..notBeInfinite(), which: ['is infinite']);
      });
    });
    group('closeTo', () {
      test('succeeds for equal numbers', () {
        1.must.beCloseTo(1, 1);
      });
      test('succeeds at less than delta away', () {
        1.must.beCloseTo(2, 2);
      });
      test('succeeds at exactly delta away', () {
        1.must.beCloseTo(2, 1);
      });
      test('fails for low values', () {
        1
            .must
            .beRejectedBy(would()..beCloseTo(3, 1), which: ['differs by <2>']);
      });
      test('fails for high values', () {
        5
            .must
            .beRejectedBy(would()..beCloseTo(3, 1), which: ['differs by <2>']);
      });
    });
  });
}
