[![pub package](https://img.shields.io/pub/v/checks.svg)](https://pub.dev/packages/checks)
[![package publisher](https://img.shields.io/pub/publisher/checks.svg)](https://pub.dev/packages/checks/publisher)

`package:checks` is a library for expressing test expectations and it features
a literate API.

## package:checks preview

`package:checks` is in preview; to provide feedback on the API, please file
[an issue][] with questions, suggestions, feature requests, or general
feedback.

For documentation about migrating from `package:matcher` to `checks`, see the
[migration guide][].

[an issue]:https://github.com/dart-lang/test/issues/new?labels=package%3Achecks&template=03_checks_feedback.md
[migration guide]:https://github.com/dart-lang/test/blob/master/pkgs/checks/doc/migrating_from_matcher.md

## Quickstart

1. Add a `dev_dependency` on `checks: ^0.2.0`.

1. Add an import for `package:checks/checks.dart`.

1. Use `checks` in your test code:

```dart
void main() {
  test('sample test', () {
    // test code here
    ...

    check(actual).equals(expected);
    check(someList).isNotEmpty();
    check(someObject).isA<Map>();
    check(someString)..startsWith('a')..endsWith('z')..contains('lmno');
  });
}
```

## Checking expectations with `checks`

Expectations start with `check`. This utility returns a `Subject`, and
expectations can be checked against the subject. Expectations are defined as
extension methods, and different expectations will be available for subjects
with different value types.

```dart
check(someValue).equals(expectedValue);
check(someList).deepEquals(expectedList);
check(someString).contains('expected pattern');
```

If a failure may not have enough context about the actual or expected values
from the expectation calls alone, add a "Reason" in the failure message by
passing a `because:` argument to `check()`.

```dart
check(
  because: 'log lines must start with the severity',
  logLines,
).every((l) => l
  ..anyOf([
    (l) => l.startsWith('ERROR'),
    (l) => l.startsWith('WARNING'),
    (l) => l.startsWith('INFO'),
  ]));
```


### Composing expectations


Multiple expectations can be checked against the same value using cascade
syntax. When multiple expectations are checked against a single value, a failure
will included descriptions of the expectations that already passed.

```dart
check(someString)
  ..startsWith('a')
  ..endsWith('z')
  ..contains('lmno');
```

Some nested checks may be not be possible to write with cascade syntax.
There is a `which` utility for this use case which takes a `Condition`.

```dart
check(someString)
  ..startsWith('a')
  // A cascade would not be possible on `length`
  ..length.which((l) => l
    ..isGreatherThan(10)
    ..isLessThan(100));
```


Some expectations return a `Subject` for another value derived from the original
value, such as the `length` extension.

```dart
check(someString).length.equals(expectedLength);
```

Fields or derived values can be extracted from objects for checking further
properties with the `has` utility.

```dart
check(someValue)
  .has((value) => value.property, 'property')
  .equals(expectedPropertyValue);
```

### Passing a set of expectations as an argument

Some expectations take arguments which are themselves expectations to apply to
other values. These expectations take `void Function(Subject)` arguments, which
check expectations when they called with a `Subject` argument.

```dart
check(someList).any((e) => e.isGreaterThan(0));
```

### Checking asynchronous expectations

Expectation extension methods checking asynchronous behavior return a `Future`.
The future should typically be awaited within the test body, however
asynchronous expectations will also ensure that the test is not considered
complete before the expectation is complete.
Expectations with no concrete end conditions, such as an expectation that a
future never completes, cannot be awaited and may cause a failure after the test
has already appeared to complete.

Asynchronous expectations do not return a `Subject`. When an expectation
extracts a derived value further expectations can be checked by passing a
`Condition`.

```dart
await check(someFuture).completes((r) => r.isGreaterThan(0));
```

Subjects for `Stream` instances must first be wrapped into a `StreamQueue` to
allow multiple expectations to test against the stream from the same state.
The `withQueue` extension can be used when a given stream instance only needs to
be checked once, or if it is a broadcast stream, but if single subscription
stream needs to have multiple expectations checked separately it should be
wrapped with a `StreamQueue`.

```dart
await check(someStream).withQueue.inOrder([
  (s) => s.emits((e) => e.equals(1)),
  (s) => s.emits((e) => e.equals(2)),
  (s) => s.emits((e) => e.equals(3)),
  (s) => s.isDone(),
]);

var someQueue = StreamQueue(someOtherStream);
await check(someQueue).emits((e) => e.equals(1));
// do something
await check(someQueue).emits((e) => e.equals(2));
// do something
```


## Writing custom expectations

Expectations are written as extensions on `Subject` with specific generics. The
library `package:checks/context.dart` gives access to a `context` getter on
`Subject` which offers capabilities for defining expectations on the subject's
value.

The `Context` allows checking an expectation with `expect`, `expectAsync` and
`expectUnawaited`, or extracting a derived value for performing other checks
with `nest` and `nestAsync`. Failures are reported by returning a `Rejection`,
or an `Extracted.rejection`, extensions should avoid throwing exceptions.

Descriptions of the clause checked by an expectations are passed through a
separate callback from the predicate which checks the value. Nesting calls are
made with a label directly. When there are no failures the clause callbacks are
not called. When a condition callback is described, the clause callbacks are
called, but the predicate callbacks are not called. Conditions can be checked
against values without throwing an exception using `softCheck` or
`softCheckAsync`.

```dart
extension CustomChecks on Subject<CustomType> {
  void someExpectation() {
    context.expect(() => ['meets this expectation'], (actual) {
      if (_expectationIsMet(actual)) return null;
      return Rejection(which: ['does not meet this expectation']);
    });
  }

  Subject<Foo> get someDerivedValue =>
      context.nest(() => ['has someDerivedValue'], (actual) {
        if (_cannotReadDerivedValue(actual)) {
          return Extracted.rejection(which: ['cannot read someDerivedValue']);
        }
        return Extracted.value(_readDerivedValue(actual));
      });

  // for field reads that will not get rejected, use `has`
  Subject<Bar> get someField => has((a) => a.someField, 'someField');
}
```

Extensions may also compose existing expectations under a single name. When
such expectations fail, the test output will refer to the individual
expectations that were called.

```dart
extension ComposedChecks on Subject<Iterable> {
  void hasLengthInRange(int min, int max) {
    length
      ..isGreaterThan(min)
      ..isLessThan(max);
  }
}
```
