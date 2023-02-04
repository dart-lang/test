// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

extension CoreChecks<T> on Subject<T> {
  /// Extracts a property of the value for further expectations.
  ///
  /// Sets up a clause that the value "has [name] that:" followed by any
  /// expectations applied to the returned [Subject].
  Subject<R> has<R>(R Function(T) extract, String name) {
    return context.nest(() => ['has $name'], (T value) {
      try {
        return Extracted.value(extract(value));
      } catch (_) {
        return Extracted.rejection(
            which: ['threw while trying to read property']);
      }
    });
  }

  /// Applies the expectations invoked in [condition] to this subject.
  ///
  /// Use this method when it would otherwise not be possible to check multiple
  /// expectations for this subject due to cascade notation already being used
  /// in a way that would conflict.
  ///
  /// ```
  /// check(something)
  ///   ..has((s) => s.foo, 'foo').equals(expectedFoo)
  ///   ..has((s) => s.bar, 'bar').which(it()
  ///     ..isLessThan(10)
  ///     ..isGreaterThan(0));
  /// ```
  void which(Condition<T> condition) => condition.apply(this);

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
      return Rejection(which: ['did not match any condition']);
    });
  }

  /// Expects that the value is assignable to type [T].
  ///
  /// If the value is a [T], returns a [Subject] for further expectations.
  Subject<R> isA<R>() {
    return context.nest<R>(() => ['is a $R'], (actual) {
      if (actual is! R) {
        return Extracted.rejection(which: ['Is a ${actual.runtimeType}']);
      }
      return Extracted.value(actual);
    }, atSameLevel: true);
  }

  /// Expects that the value is equal to [other] according to [operator ==].
  void equals(T other) {
    context.expect(() => prefixFirst('equals ', literal(other)), (actual) {
      if (actual == other) return null;
      return Rejection(which: ['are not equal']);
    });
  }

  /// Expects that the value is [identical] to [other].
  void identicalTo(T other) {
    context.expect(() => prefixFirst('is identical to ', literal(other)),
        (actual) {
      if (identical(actual, other)) return null;
      return Rejection(which: ['is not identical']);
    });
  }
}

extension BoolChecks on Subject<bool> {
  void isTrue() {
    context.expect(
      () => ['is true'],
      (actual) => actual
          ? null // force coverage
          : Rejection(),
    );
  }

  void isFalse() {
    context.expect(
      () => ['is false'],
      (actual) => !actual
          ? null // force coverage
          : Rejection(),
    );
  }
}

extension NullabilityChecks<T> on Subject<T?> {
  Subject<T> isNotNull() {
    return context.nest<T>(() => ['is not null'], (actual) {
      if (actual == null) return Extracted.rejection();
      return Extracted.value(actual);
    }, atSameLevel: true);
  }

  void isNull() {
    context.expect(() => const ['is null'], (actual) {
      if (actual != null) return Rejection();
      return null;
    });
  }
}
