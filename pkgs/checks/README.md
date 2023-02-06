# Checking expectations with `checks`

Expectations start with `check`. This utility returns a `Subject`, and
expectations can be checked against the subject. Expectations are defined as
extension methods, and different expectations will be available for subjects
with different value types.

```dart
check(someValue).equals(expectedValue);
check(someList).deepEquals(expectedList);
check(someString).contains('expected pattern');
```

Multiple expectations can be checked against the same value using cascade
syntax. When multiple expectations are checked against a single value, a failure
will included descriptions of the expectations that already passed.

```dart
check(someString)
  ..startsWith('a')
  ..endsWith('z')
  ..contains('lmno');
```

Some expectations return a `Subject` for another value derived from the original
value - for instance reading a field or awaiting the result of a Future.

```dart
check(someString).length.equals(expectedLength);
(await check(someFuture).completes()).equals(expectedCompletion);
```

Fields can be extracted from objects for checking further properties with the
`has` utility.

```dart
check(someValue)
  .has((value) => value.property, 'property')
  .equals(expectedPropertyValue);
```

Some expectations take arguments which are themselves expectations to apply to
other values. These expectations take `Condition` arguments, which check
expectations when they are applied to a `Subject`. The `ConditionSubject`
utility acts as both a condition and a subject. Any expectations checked on the
value as a subject will be recorded and replayed when it is applied as a
condition. The `it()` utility returns a `ConditionSubject`.

```dart
check(someList).any(it()..isGreaterThan(0));
```

Some complicated checks may be difficult to write with parenthesized awaited
expressions, or impossible to write with cascade syntax. There are `which`
utilities for both use cases which take a `Condition`.

```dart
check(someString)
  ..startsWith('a')
  // A cascade would not be possible on `length`
  ..length.which(it()
    ..isGreatherThan(10)
    ..isLessThan(100));

await check(someFuture)
    .completes()
    .which(it()..equals(expectedCompletion));
```

# Writing custom expectations

Expectations are written as extension on `Subject` with specific generics. The
library `package:checks/context.dart` gives access to a `context` getter on
`Subject` which offers capabilities for defining expectations on the subject's
value.

The `Context` allows checking a expectation with `expect`, `expectAsync` and
`expectUnawaited`, or extracting a derived value for performing other checks
with `nest` and `nestAsync`. Failures are reported by returning a `Rejection`,
or an `Extracted.rejection`, extensions should avoid throwing exceptions.

Descriptions of the clause checked by an expectations are passed through a
separate callback from the predicate which checks the value. Nesting calls are
made with a label directly. When there are no failures the clause callbacks are
not called. When a `Condition` is described, the clause callbacks are called,
but the predicate callbacks are not called. Conditions can be checked against
values without throwing an exception using `softCheck` or `softCheckAsync`.

```dart
extension CustomChecks on Subject<CustomType> {
  void someExpectation() {
    context.expect(() => ['meets this expectation'], (actual) {
      if (_expectationIsMet(actual)) return null;
      return Rejection(which: ['does not meet this expectation']);
    });
  }

  Subject<Foo> get someDerivedValue =>
      context.nest('has someDerivedValue', (actual) {
        if (_cannotReadDerivedValue(actual)) {
          return Extracted.rejection(which: ['cannot read someDerivedValue']);
        }
        return Extracted.value(_readDerivedValue(actual));
      });

  // for field reads that will not get rejected, use `has`
  Subject<Bar> get someField => has((a) => a.someField, 'someField');
}
```
