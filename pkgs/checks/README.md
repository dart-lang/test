# Checking expectation with `checks`

Expectations start with `checkThat`. This utility returns a `Subject`, and
expectations can be checked against the subject. Expectations are defined as
extension methods, and different expectations will be available for subjects
with different value types.

```dart
checkThat(someValue).equals(expectedValue);
checkThat(someList).deepEquals(expectedList);
checkThat(someString).contains('expected pattern');
```

Multiple expectations can be checked against the same value using cascade
syntax. When multiple expectations are checked against a single value, a failure
will included descriptions of the expectations that already passed.

```dart
checkThat(someString)
  ..startsWith('a')
  ..endsWith('z')
  ..contains('lmno');
```

Some expectations return a `Subject` for another value derived from the original
value - for instance reading a field or awaiting the result of a Future.

```dart
checkThat(someString).length.equals(expectedLength);
(await checkThat(someFuture).completes()).equals(expectedCompletion);
```

Fields can be extracted from objects for checking further properties with the
`has` utility.

```dart
checkThat(someValue)
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
checkThat(someList).any(it()..isGreaterThan(0));
```

Some complicated checks may be difficult to write with parenthesized awaited
expressions, or impossible to write with cascade syntax. There are `which`
utilities for both use cases which take a `Condition`.

```dart
checkThat(someString)
  ..startsWith('a')
  // A cascade would not be possible on `length`
  ..length.which(it()
    ..isGreatherThan(10)
    ..isLessThan(100));

await checkThat(someFuture)
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

# Trying Checks as a Preview

1.  Replace the existing `package:test/test.dart` import with
    `package:test/scaffolding.dart`.

1.  Add an import to `package:checks/checks.dart`.

1.  For an incremental migration within the test, add an import to
    `package:test/expect.dart`. Remove it to surface errors in tests that still
    need to be migrated, or keep it in so the tests work without being fully
    migrated.

1.  Migrate the test cases.

# Migrating from Matchers

Replace calls to `expect` with a call to `checkThat` passing the first argument.
When a direct replacement is available, change the second argument from calling
a function returning a Matcher, to calling the extension method on the
`Subject`.

When a non-matcher argument is used for the expected value, it would have been
wrapped with `equals` automatically. See below, `.equals` may not always be the
correct replacement in `package:checks`.

```dart
expect(actual, expected);
checkThat(actual).equals(expected);
// or maybe
checkThat(actual).deepEquals(expected);
```

## Differences in behavior from matcher

-   The `equals` Matcher performed a deep equality check on collections.
    `.equals()` expectation will only correspond to [operator ==] so some tests
    may need to replace `.equals()` with `.deepEquals()`.
