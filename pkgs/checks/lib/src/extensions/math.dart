// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

extension NumChecks on Subject<num> {
  /// Expects that [num.isNaN] is true.
  void isNaN() {
    context.expect(() => ['is not a number (NaN)'], (actual) {
      if (actual.isNaN) return null;
      return Rejection(which: ['is a number']);
    });
  }

  /// Expects that [num.isNaN] is false.
  void isNotNaN() {
    context.expect(() => ['is a number (not NaN)'], (actual) {
      if (!actual.isNaN) return null;
      return Rejection(which: ['is not a number (NaN)']);
    });
  }

  /// Expects that [num.isNegative] is true.
  void isNegative() {
    context.expect(() => ['is negative'], (actual) {
      if (actual.isNegative) return null;
      return Rejection(which: ['is not negative']);
    });
  }

  /// Expects that [num.isNegative] is false.
  void isNotNegative() {
    context.expect(() => ['is not negative'], (actual) {
      if (!actual.isNegative) return null;
      return Rejection(which: ['is negative']);
    });
  }

  /// Expects that [num.isFinite] is true.
  void isFinite() {
    context.expect(() => ['is finite'], (actual) {
      if (actual.isFinite) return null;
      return Rejection(which: ['is not finite']);
    });
  }

  /// Expects that [num.isFinite] is false.
  ///
  /// Satisfied by [double.nan], [double.infinity] and
  /// [double.negativeInfinity].
  void isNotFinite() {
    context.expect(() => ['is not finite'], (actual) {
      if (!actual.isFinite) return null;
      return Rejection(which: ['is finite']);
    });
  }

  /// Expects that [num.isInfinite] is true.
  ///
  /// Satisfied by [double.infinity] and [double.negativeInfinity].
  void isInfinite() {
    context.expect(() => ['is infinite'], (actual) {
      if (actual.isInfinite) return null;
      return Rejection(which: ['is not infinite']);
    });
  }

  /// Expects that [num.isInfinite] is false.
  ///
  /// Satisfied by [double.nan] and finite numbers.
  void isNotInfinite() {
    context.expect(() => ['is not infinite'], (actual) {
      if (!actual.isInfinite) return null;
      return Rejection(which: ['is infinite']);
    });
  }

  /// Expects that the difference between this number and [other] is less than
  /// or equal to [delta].
  void isCloseTo(num other, num delta) {
    context.expect(() => ['is within <$delta> of <$other>'], (actual) {
      final difference = (other - actual).abs();
      if (difference <= delta) return null;
      return Rejection(which: ['differs by <$difference>']);
    });
  }
}

extension ComparableChecks<T> on Subject<Comparable<T>> {
  /// Expects that this number is greater than [other].
  void isGreaterThan(T other) {
    context.expect(() => prefixFirst('is greater than ', literal(other)),
        (actual) {
      if (actual.compareTo(other) > 0) return null;
      return Rejection(
          which: prefixFirst('is not greater than ', literal(other)));
    });
  }

  /// Expects that this number is greater than or equal to [other].
  void isGreaterOrEqual(T other) {
    context.expect(
        () => prefixFirst('is greater than or equal to ', literal(other)),
        (actual) {
      if (actual.compareTo(other) >= 0) return null;
      return Rejection(
          which:
              prefixFirst('is not greater than or equal to ', literal(other)));
    });
  }

  /// Expects that this number is less than [other].
  void isLessThan(T other) {
    context.expect(() => prefixFirst('is less than ', literal(other)),
        (actual) {
      if (actual.compareTo(other) < 0) return null;
      return Rejection(which: prefixFirst('is not less than ', literal(other)));
    });
  }

  /// Expects that this number is less than or equal to [other].
  void isLessOrEqual(T other) {
    context
        .expect(() => prefixFirst('is less than or equal to ', literal(other)),
            (actual) {
      if (actual.compareTo(other) <= 0) return null;
      return Rejection(
          which: prefixFirst('is not less than or equal to ', literal(other)));
    });
  }
}
