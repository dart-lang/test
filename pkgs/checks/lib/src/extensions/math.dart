// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

extension NumChecks on Check<num> {
  /// Expects that this number is greater than [other].
  void operator >(num other) {
    context.expect(() => ['is greater than ${literal(other)}'], (actual) {
      if (actual > other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['is not greater than ${literal(other)}']);
    });
  }

  /// Expects that this number is greater than  or equal to [other].
  void operator >=(num other) {
    context.expect(() => ['is greater than ${literal(other)}'], (actual) {
      if (actual >= other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['is not greater than or equal to ${literal(other)}']);
    });
  }

  /// Expects that this number is less than [other].
  void operator <(num other) {
    context.expect(() => ['is less than ${literal(other)}'], (actual) {
      if (actual < other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['is not less than ${literal(other)}']);
    });
  }

  /// Expects that this number is less than  or equal to [other].
  void operator <=(num other) {
    context.expect(() => ['is less than ${literal(other)}'], (actual) {
      if (actual <= other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['is not less than or equal to ${literal(other)}']);
    });
  }

  /// Expects that `isNaN` is true.
  void isNaN() {
    context.expect(() => ['is not a number (NaN)'], (actual) {
      if (actual.isNaN) return null;
      return Rejection(actual: literal(actual), which: ['is a number']);
    });
  }

  /// Expects that `isNaN` is false.
  void isNotNaN() {
    context.expect(() => ['is a number (not NaN)'], (actual) {
      if (!actual.isNaN) return null;
      return Rejection(
          actual: literal(actual), which: ['is not a number (NaN)']);
    });
  }

  /// Expects that the difference between this number and [other] is less than
  /// or equal to [delta].
  void isCloseTo(num other, num delta) {
    context.expect(() => ['is within ${literal(delta)} of ${literal(other)}'],
        (actual) {
      final difference = (other - actual).abs();
      if (difference <= delta) return null;
      return Rejection(
          actual: literal(actual),
          which: ['differs by ${literal(difference)}']);
    });
  }
}
