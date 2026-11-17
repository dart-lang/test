// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart' as meta;

import '../../context.dart';

extension CoreChecks<T> on Subject<T> {
  /// Extracts a property of the value for further expectations.
  ///
  /// Sets up a clause that the value "has [name] that:" followed by any
  /// expectations applied to the returned [Subject].
  ///
  /// ```dart
  /// check(RegExp('^abc'))
  ///   .has('pattern', (s) => s.pattern)
  ///   .equals('^abc');
  /// ```
  ///
  /// For checking properties of custom types it's common define extension
  /// methods using `has`:
  /// ```dart
  /// extension RegExpChecks on Subject<RegExp> {
  ///   Subject<String> get pattern => has('pattern', (s) => s.pattern);
  ///   Subject<bool> get isUnicode => has('isUnicode', (s) => s.isUnicode);
  /// }
  ///
  /// void main() {
  ///   check(RegExp('^abc'))
  ///     ..pattern.contains('abc')
  ///     ..isUnicode.isTrue;
  /// }
  /// ```
  ///
  /// {@example /example/core/subject/has.dart}
  @meta.useResult
  Subject<R> has<R>(String name, R Function(T) extract) => context.nest(
    () => ['has $name'],
    addPredicate: (predicateNoun) => 'has $name: $predicateNoun',
    (value) {
      try {
        return Extracted.value(extract(value));
      } catch (e, st) {
        return Extracted.rejection(
          which: [
            ...prefixFirst(
              'threw while trying to read $name: ',
              postfixLast(' at:', literal(e)),
            ),
            ...indent(LineSplitter.split(st.toString())),
          ],
        );
      }
    },
  );

  /// Applies the expectations invoked in [condition] to this subject.
  ///
  /// Use this method when it would otherwise not be possible to check multiple
  /// expectations for this subject due to cascade notation already being used
  /// in a way that would conflict.
  ///
  /// ```
  /// check(something)
  ///   ..has('foo', (s) => s.foo).equals(expectedFoo)
  ///   ..has('bar', (s) => s.bar).which(.it()
  ///     ..isLessThan(10)
  ///     ..isGreaterThan(0));
  /// ```
  ///
  /// {@example /example/core/subject/which.dart}
  void which(Condition<T> condition) => condition.applySync(this);

  /// Check that the expectations invoked in [condition] are not satisfied by
  /// this value.
  ///
  /// Asynchronous expectations are not allowed in [condition].
  ///
  /// {@example /example/core/subject/not.dart}
  void not(Condition<T> condition) {
    context.expect(
      () => ['is not a value that:', ...indent(condition.describeSync())],
      (actual) {
        if (condition.softCheckSync(actual) != null) return null;
        return Rejection(
          which: ['is a value that:', ...indent(condition.describeSync())],
        );
      },
    );
  }

  /// Expects that the value satisfies the expectations invoked in at least one
  /// condition from [conditions].
  ///
  /// Asynchronous expectations are not allowed in [conditions].
  ///
  /// {@example /example/core/subject/any_of.dart}
  void anyOf(Iterable<Condition<T>> conditions) {
    context.expect(
      () => prefixFirst('matches any condition in ', literal(conditions)),
      (actual) {
        for (final condition in conditions) {
          if (condition.softCheckSync(actual) == null) return null;
        }
        return Rejection(which: ['did not match any condition']);
      },
    );
  }

  /// Expects that the value is assignable to type [T].
  ///
  /// If the value is a [T], returns a [Subject] for further expectations.
  ///
  /// {@example /example/core/subject/is_a.dart}
  Subject<R> isA<R>([Condition<R>? and]) {
    return context.nest<R>(() => ['is a $R'], atSameLevel: true, (actual) {
      if (actual is! R) {
        return Extracted.rejection(which: ['is a ${actual.runtimeType}']);
      }
      return Extracted.value(actual);
    }, nestedCondition: and);
  }

  /// Expects that the value is not assignable to type [R].
  ///
  /// {@example /example/core/subject/is_not_a.dart}
  void isNotA<R>() {
    context.expect(() => ['is not a $R'], (actual) {
      if (actual is R) {
        return Rejection(which: ['is a $R']);
      }
      return null;
    });
  }

  /// Expects that the value is equal to [other] according to [operator ==].
  ///
  /// {@example /example/core/subject/equals.dart}
  void equals(T other) {
    context.expect(
      () => prefixFirst('equals ', literal(other)),
      predicateNoun: () => literal(other).singleOrNull,
      (actual) {
        if (actual == other) return null;
        return Rejection(which: ['is not equal']);
      },
    );
  }

  /// Expects that the value is [identical] to [other].
  ///
  /// {@example /example/core/subject/identical_to.dart}
  void identicalTo(T other) {
    context.expect(
      () => prefixFirst('is identical to ', literal(other)),
      predicateNoun: () => literal(other).singleOrNull,
      (actual) {
        if (identical(actual, other)) return null;
        return Rejection(which: ['is not identical']);
      },
    );
  }
}

extension BoolChecks on Subject<bool> {
  /// Expects that the value is `true`.
  ///
  /// {@example /example/core/bool/is_true.dart}
  void get isTrue {
    context.expect(
      () => ['is true'],
      predicateNoun: () => 'true',
      (actual) => actual
          ? null // force coverage
          : Rejection(),
    );
  }

  /// Expects that the value is `false`.
  ///
  /// {@example /example/core/bool/is_false.dart}
  void get isFalse {
    context.expect(
      () => ['is false'],
      predicateNoun: () => 'false',
      (actual) => !actual
          ? null // force coverage
          : Rejection(),
    );
  }
}

extension NullableChecks<T> on Subject<T?> {
  /// Expects that the value is not `null`, and returns a [Subject] for the
  /// non-nullable value.
  ///
  /// {@example /example/core/nullable/is_not_null.dart}
  Subject<T> isNotNull([Condition<T>? and]) {
    return context.nest<T>(() => ['is not null'], atSameLevel: true, (actual) {
      if (actual == null) return Extracted.rejection();
      return Extracted.value(actual);
    }, nestedCondition: and);
  }

  /// Expects that the value is `null`.
  ///
  /// {@example /example/core/nullable/is_null.dart}
  void get isNull {
    context.expect(() => const ['is null'], predicateNoun: () => 'null', (
      actual,
    ) {
      if (actual == null) return null;
      return Rejection();
    });
  }
}

extension ComparableChecks<T> on Subject<Comparable<T>> {
  /// Expects that this value is greater than [other].
  ///
  /// {@example /example/core/comparable/is_greater_than.dart}
  void isGreaterThan(T other) {
    context.expect(
      () => prefixFirst('is greater than ', literal(other)),
      predicateNoun: () {
        final l = literal(other).singleOrNull;
        return l != null ? 'a value > $l' : null;
      },
      (actual) {
        if (actual.compareTo(other) > 0) return null;
        return Rejection(
          which: prefixFirst('is not greater than ', literal(other)),
        );
      },
    );
  }

  /// Expects that this value is greater than or equal to [other].
  ///
  /// {@example /example/core/comparable/is_greater_or_equal.dart}
  void isGreaterOrEqual(T other) {
    context.expect(
      () => prefixFirst('is greater than or equal to ', literal(other)),
      predicateNoun: () {
        final l = literal(other).singleOrNull;
        return l != null ? 'a value >= $l' : null;
      },
      (actual) {
        if (actual.compareTo(other) >= 0) return null;
        return Rejection(
          which: prefixFirst(
            'is not greater than or equal to ',
            literal(other),
          ),
        );
      },
    );
  }

  /// Expects that this value is less than [other].
  ///
  /// {@example /example/core/comparable/is_less_than.dart}
  void isLessThan(T other) {
    context.expect(
      () => prefixFirst('is less than ', literal(other)),
      predicateNoun: () {
        final l = literal(other).singleOrNull;
        return l != null ? 'a value < $l' : null;
      },
      (actual) {
        if (actual.compareTo(other) < 0) return null;
        return Rejection(
          which: prefixFirst('is not less than ', literal(other)),
        );
      },
    );
  }

  /// Expects that this value is less than or equal to [other].
  ///
  /// {@example /example/core/comparable/is_less_or_equal.dart}
  void isLessOrEqual(T other) {
    context.expect(
      () => prefixFirst('is less than or equal to ', literal(other)),
      predicateNoun: () {
        final l = literal(other).singleOrNull;
        return l != null ? 'a value <= $l' : null;
      },
      (actual) {
        if (actual.compareTo(other) <= 0) return null;
        return Rejection(
          which: prefixFirst('is not less than or equal to ', literal(other)),
        );
      },
    );
  }
}
