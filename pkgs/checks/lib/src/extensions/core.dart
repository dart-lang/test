// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

extension CoreChecks<T> on Check<T> {
  /// Extracts a property of the value for further expectations.
  ///
  /// Sets up a clause that the value "has [name] that:" followed by any
  /// expectations applied to the returned [Check].
  Check<R> has<R>(R Function(T) extract, String name) {
    return context.nest('has $name', (T value) {
      try {
        return Extracted.value(extract(value));
      } catch (_) {
        return Extracted.rejection(
            actual: literal(value),
            which: ['threw while trying to read property']);
      }
    });
  }

  /// Checks the expectations invoked in [condition] against this value.
  ///
  /// Use this method when it would otherwise not be possible to check multiple
  /// properties of this value due to cascade notation already being used in a
  /// way that would conflict.
  ///
  /// ```
  /// checkThat(something)
  ///   ..has((s) => s.foo, 'foo').equals(expectedFoo)
  ///   ..has((s) => s.bar, 'bar').that((b) => b
  ///     ..isLessThan(10)
  ///     ..isGreaterThan(0));
  /// ```
  void that(Condition<T> condition) => condition.apply(this);

  /// Check that the expectations invoked in [condition] are not satisfied by
  /// this value.
  ///
  /// Asynchronous expectations are not allowed in [condition].
  void not(Condition<T> condition) {
    context.expect(
      () => ['is not a value that:', ...indent(describe(condition))],
      (actual) {
        if (softCheck(actual, condition) != null) return null;
        return Rejection(
          actual: literal(actual),
          which: ['is a value that: ', ...indent(describe(condition))],
        );
      },
    );
  }

  /// Expects that the value satisfies the expectations invoked in at least one
  /// condition from [conditions].
  ///
  /// Asynchronous expectations are not allowed in [conditions].
  void anyOf(Iterable<Condition<T>> conditions) {
    context.expect(
        () => prefixFirst('matches any condition in ', literal(conditions)),
        (actual) {
      for (final condition in conditions) {
        if (softCheck(actual, condition) == null) return null;
      }
      return Rejection(
          actual: literal(actual), which: ['did not match any condition']);
    });
  }

  /// Expects that the value is assignable to type [T].
  ///
  /// If the value is a [T], returns a [Check<T>] for further expectations.
  Check<R> isA<R>() {
    return context.nest<R>('is a $R', (actual) {
      if (actual is! R) {
        return Extracted.rejection(
            actual: literal(actual), which: ['Is a ${actual.runtimeType}']);
      }
      return Extracted.value(actual);
    }, atSameLevel: true);
  }

  /// Expects that the value is equal to [other] according to [operator ==].
  void equals(T other) {
    context.expect(() => prefixFirst('equals ', literal(other)), (actual) {
      if (actual == other) return null;
      return Rejection(actual: literal(actual), which: ['are not equal']);
    });
  }

  /// Expects that the value is [identical] to [other].
  void identicalTo(T other) {
    context.expect(() => prefixFirst('is identical to ', literal(other)),
        (actual) {
      if (identical(actual, other)) return null;
      return Rejection(actual: literal(actual), which: ['is not identical']);
    });
  }
}

extension BoolChecks on Check<bool> {
  void isTrue() {
    context.expect(
      () => ['is true'],
      (actual) => actual
          ? null // force coverage
          : Rejection(actual: literal(actual)),
    );
  }

  void isFalse() {
    context.expect(
      () => ['is false'],
      (actual) => !actual
          ? null // force coverage
          : Rejection(actual: literal(actual)),
    );
  }
}

extension NullabilityChecks<T> on Check<T?> {
  Check<T> isNotNull() {
    return context.nest<T>('is not null', (actual) {
      if (actual == null) return Extracted.rejection(actual: literal(actual));
      return Extracted.value(actual);
    }, atSameLevel: true);
  }

  void isNull() {
    context.expect(() => const ['is null'], (actual) {
      if (actual != null) return Rejection(actual: literal(actual));
      return null;
    });
  }
}
