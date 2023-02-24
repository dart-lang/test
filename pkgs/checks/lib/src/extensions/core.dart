// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:checks/context.dart';
import 'package:meta/meta.dart' as meta;

extension CoreChecks<T> on Subject<T> {
  /// Extracts a property of the value for further expectations.
  ///
  /// Sets up a clause that the value "has [name] that:" followed by any
  /// expectations applied to the returned [Subject].
  @meta.useResult
  Subject<R> has<R>(R Function(T) extract, String name) {
    return context.nest(() => ['has $name'], (value) {
      try {
        return Extracted.value(extract(value));
      } catch (e, st) {
        return Extracted.rejection(which: [
          ...prefixFirst('threw while trying to read $name: ', literal(e)),
          ...(const LineSplitter()).convert(st.toString())
        ]);
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

extension NullableChecks<T> on Subject<T?> {
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

extension ComparableChecks<T> on Subject<Comparable<T>> {
  /// Expects that this value is greater than [other].
  void isGreaterThan(T other) {
    context.expect(() => prefixFirst('is greater than ', literal(other)),
        (actual) {
      if (actual.compareTo(other) > 0) return null;
      return Rejection(
          which: prefixFirst('is not greater than ', literal(other)));
    });
  }

  /// Expects that this value is greater than or equal to [other].
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

  /// Expects that this value is less than [other].
  void isLessThan(T other) {
    context.expect(() => prefixFirst('is less than ', literal(other)),
        (actual) {
      if (actual.compareTo(other) < 0) return null;
      return Rejection(which: prefixFirst('is not less than ', literal(other)));
    });
  }

  /// Expects that this value is less than or equal to [other].
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
