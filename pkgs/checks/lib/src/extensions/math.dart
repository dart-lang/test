// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../context.dart';

extension NumChecks on Subject<num> {
  /// Expects that [num.isNaN] is true.
  void get isNaN {
    context.expect(
      () => ['is not a number (NaN)'],
      predicateNoun: () => 'NaN',
      (actual) => actual.isNaN ? null : Rejection(),
    );
  }

  /// Expects that [num.isNaN] is false.
  void get isNotNaN {
    context.expect(
      () => ['is a number (not NaN)'],
      predicateNoun: () => 'a number (not NaN)',
      (actual) => actual.isNaN ? Rejection() : null,
    );
  }

  /// Expects that [num.isNegative] is true.
  void get isNegative {
    context.expect(
      () => ['is negative'],
      predicateNoun: () => 'a negative number',
      (actual) =>
          actual.isNegative ? null : Rejection(which: ['is not negative']),
    );
  }

  /// Expects that [num.isNegative] is false.
  void get isNotNegative {
    context.expect(
      () => ['is not negative'],
      predicateNoun: () => 'a non-negative number',
      (actual) => actual.isNegative ? Rejection(which: ['is negative']) : null,
    );
  }

  /// Expects that [num.isFinite] is true.
  void get isFinite {
    context.expect(
      () => ['is finite'],
      predicateNoun: () => 'a finite number',
      (actual) => actual.isFinite ? null : Rejection(which: ['is not finite']),
    );
  }

  /// Expects that [num.isFinite] is false.
  ///
  /// Satisfied by [double.nan], [double.infinity] and
  /// [double.negativeInfinity].
  void get isNotFinite {
    context.expect(
      () => ['is not finite'],
      predicateNoun: () => 'a non-finite number',
      (actual) => actual.isFinite ? Rejection(which: ['is finite']) : null,
    );
  }

  /// Expects that [num.isInfinite] is true.
  ///
  /// Satisfied by [double.infinity] and [double.negativeInfinity].
  void get isInfinite {
    context.expect(
      () => ['is infinite'],
      predicateNoun: () => 'an infinite number',
      (actual) =>
          actual.isInfinite ? null : Rejection(which: ['is not infinite']),
    );
  }

  /// Expects that [num.isInfinite] is false.
  ///
  /// Satisfied by [double.nan] and finite numbers.
  void get isNotInfinite {
    context.expect(
      () => ['is not infinite'],
      predicateNoun: () => 'a non-infinite number',
      (actual) => actual.isInfinite ? Rejection(which: ['is infinite']) : null,
    );
  }

  /// Expects that the difference between this number and [other] is less than
  /// or equal to [delta].
  void isCloseTo(num other, num delta) {
    context.expect(
      () => ['is within <$delta> of <$other>'],
      predicateNoun: () =>
          switch ((literal(other).singleOrNull, literal(delta).singleOrNull)) {
            (final other?, final delta?) => 'a value within $delta of $other',
            _ => null,
          },
      (actual) {
        final difference = (other - actual).abs();
        if (difference <= delta) return null;
        return Rejection(which: ['differs by <$difference>']);
      },
    );
  }
}
