import 'package:checks/context.dart';

extension TypeChecks on Check<Object?> {
  /// Expects that the value is assignable to type [T].
  ///
  /// If the value is a [T], returns a [Check<T>] for further expectations.
  Check<T> isA<T>() {
    return context.nest<T>('is a $T', (actual) {
      if (actual is! T) {
        return Extracted.rejection(
            actual: literal(actual), which: ['Is a ${actual.runtimeType}']);
      }
      return Extracted.value(actual);
    }, atSameLevel: true);
  }
}

extension HasField<T> on Check<T> {
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
  R that<R>(R Function(Check<T>) condition) => condition(this);

  /// Check that the expectations invoked in [condition] are not satisfied by
  /// this value.
  ///
  /// Asynchronous expectations are not allowed in [condition].
  void not(void Function(Check<T>) condition) {
    context.expect(() {
      return ['is not a value that:', ...indent(describe(condition))];
    }, (actual) {
      if (softCheck(actual, condition) != null) return null;
      return Rejection(
          actual: literal(actual),
          which: ['is a value that: ', ...indent(describe(condition))]);
    });
  }
}

extension BoolChecks on Check<bool> {
  void isTrue() {
    context.expect(() => ['is true'],
        (actual) => actual ? null : Rejection(actual: literal(actual)));
  }

  void isFalse() {
    context.expect(() => ['is false'],
        (actual) => !actual ? null : Rejection(actual: literal(actual)));
  }
}

extension EqualityChecks<T> on Check<T> {
  /// Expects that the value is equal to [other] according to [operator ==].
  void equals(T other) {
    context.expect(() => ['equals ${literal(other)}'], (actual) {
      if (actual == other) return null;
      return Rejection(actual: literal(actual), which: ['are not equal']);
    });
  }

  /// Expects that the value is [identical] to [other].
  void identicalTo(T other) {
    context.expect(() => ['is identical to ${literal(other)}'], (actual) {
      if (identical(actual, other)) return null;
      return Rejection(actual: literal(actual), which: ['is not identical']);
    });
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

extension StringChecks on Check<String> {
  /// Expects that the value contains [pattern] according to [String.contains];
  void contains(Pattern pattern) {
    context.expect(() => ['contains $pattern'], (actual) {
      if (actual.contains(pattern)) return null;
      return Rejection(
          actual: literal(actual), which: ['Does not contain $pattern']);
    });
  }
}
