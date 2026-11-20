[![pub package](https://img.shields.io/pub/v/checks.svg)](https://pub.dev/packages/checks)
[![package publisher](https://img.shields.io/pub/publisher/checks.svg)](https://pub.dev/packages/checks/publisher)

`package:checks` is a library for expressing test expectations with a
statically typed, literate API.

## Package status

`package:checks` is currently in preview under the `labs.dart.dev` publisher
while we gather final feedback ahead of a `1.0.0` release and graduation to
`dart.dev`. The current API is expected to be close to its stable `1.0.0` shape
and is ready for use in test suites, though breaking changes remain possible
before `1.0.0`.

To provide feedback on the API, please file [an issue][] with questions,
suggestions, feature requests, or general feedback.

For documentation about converting your usage of `package:matcher` to `checks`,
see the [migration guide][].

[an issue]: https://github.com/dart-lang/test/issues/new?labels=package%3Achecks&template=checks.md
[migration guide]: https://github.com/dart-lang/test/blob/master/pkgs/checks/doc/migrating_from_matcher.md

## Quickstart

1. Add a `dev_dependency` on `checks` (`dart pub add dev:checks`). `checks`
   `^0.4.0` requires Dart `^3.11.0`.

1. Import `package:checks/checks.dart`. For a complete migration, eliminating
   uses of `expect`, replace the import of `package:test/test.dart` with
   `package:test/scaffolding.dart`.

1. Use `checks` in your test code:

```dart
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('sample test', () {
    // test code here
    ...

    check(actual).equals(expected);
    check(someList).isNotEmpty;
    check(someObject).isA<Map>();
    check(someString)
      ..startsWith('a')
      ..endsWith('z')
      ..contains('lmno');
  });
}
```

## Checking expectations with `checks`

Expectations start with `check`. This utility returns a `Subject`, and
expectations can be checked against the subject. Expectations are defined as
extension methods and getters, and different expectations are available for
subjects with different value types.

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
).every(
  .it()
    ..anyOf([
      .it()..startsWith('ERROR'),
      .it()..startsWith('WARNING'),
      .it()..startsWith('INFO'),
    ]),
);
```

### Composing expectations

Multiple expectations can be checked against the same value using cascade
syntax. When multiple expectations are checked against a single value, a failure
will include descriptions of the expectations that already passed.

```dart
check(someString)
  ..startsWith('a')
  ..endsWith('z')
  ..contains('lmno');
```

Some nested checks may not be possible to write with cascade syntax. There is a
`which` utility for this use case which takes a `Condition`.

```dart
check(someString)
  ..startsWith('a')
  // A cascade would not be possible on `length`
  ..length.which(
    .it()
      ..isGreaterThan(10)
      ..isLessThan(100),
  );
```

Some expectations narrow the `Subject` type or return a `Subject` for a value
derived from the original value, such as `isA<T>()`, `isNotNull()`, or `length`.
Fields or arbitrary derived values can be extracted with the `has` utility.

```dart
check(someObject).isA<String>().startsWith('a');
check(nullableString).isNotNull().isNotEmpty;
check(someString).length.equals(expectedLength);
check(someValue)
    .has('property', (value) => value.property)
    .equals(expectedPropertyValue);
```

Narrowing expectations such as `isA` and `isNotNull` also accept an optional
`Condition` argument for checking nested expectations inside a cascade:

```dart
check(someList)
  ..isNotEmpty
  ..first.isA<String>(.it()..startsWith('prefix'));
```

### Passing expectations around as values

A `Condition<T>` is an object representing a set of recorded expectations that
can be stored, passed around, and applied later to a `Subject<T>`. Built-in
combinators like `any`, `every`, `not`, `anyOf`, and `which` accept `Condition`
arguments created with the `.it()` dot shorthand (or `Condition.it<T>()` when
the target type cannot be inferred from context).

```dart
check(someList).any(.it()..isGreaterThan(0));

final isPositive = Condition.it<int>()..isGreaterThan(0);
check(someList).every(isPositive);
```

Your own test helpers and table-driven tests can also accept or store
`Condition<T>` values and run them against a subject with `.which(condition)`
(or `await condition.apply(check(value))` when the condition may include
asynchronous expectations):

```dart
void checkUser(String id, Condition<User> condition) {
  check(fetchUser(id)).which(condition);
}

checkUser('42', .it()..has('name', (u) => u.name).equals('Alice'));
```

### Checking asynchronous expectations

Expectation extension methods checking asynchronous behavior return a `Future`.
The future should typically be awaited within the test body when subsequent
steps depend on it, however asynchronous expectations also mark the test as
pending so it is not considered complete before the expectation finishes.
Expectations with no concrete end conditions, such as `doesNotComplete`, return
immediately and cannot be awaited; if the future later completes, they report a
failure even after the test has appeared to complete.

Asynchronous expectations that extract a value (such as `completes`, `throws`,
`emits`, `emitsError`, and `prints`) accept an optional `Condition` argument and
also return a `Future<Subject<T>>`. Further expectations can be checked by
passing a `Condition`, chaining `.which(...)`, or awaiting the returned
`Subject`:

```dart
await check(someFuture).completes(.it()..isGreaterThan(0));

await check(someFuture).completes().which(
  .it()
    ..isGreaterThan(0)
    ..isLessThan(100),
);

final value = await check(someFuture).completes();
value.isGreaterThan(0);
```

Subjects for `Stream` instances must first be wrapped into a `StreamQueue`
(from `package:async/async.dart`) to allow multiple expectations to test against
the stream from the same state. The `withQueue` extension can be used when a
given stream instance only needs to be checked once, or if it is a broadcast
stream, but if a single-subscription stream needs to have multiple expectations
checked separately it should be wrapped with a `StreamQueue`.

```dart
await check(someStream).withQueue.inOrder([
  .it()..emits(.it()..equals(1)),
  .it()..emits(.it()..equals(2)),
  .it()..emits(.it()..equals(3)),
  .it()..isDone,
]);

var someQueue = StreamQueue(someOtherStream);
await check(someQueue).emits(.it()..equals(1));
// do something
await check(someQueue).emits(.it()..equals(2));
// do something
```

## Writing custom expectations

Expectations are written as extensions on `Subject` with specific generics. Many
domain-specific expectations can be written using only
`package:checks/checks.dart` by composing existing expectations and `has`. When
composed expectations fail, the test output refers to the underlying
expectations that were called.

```dart
extension ComposedChecks on Subject<Iterable<Object?>> {
  void hasLengthInRange(int min, int max) {
    length
      ..isGreaterThan(min)
      ..isLessThan(max);
  }
}

extension CustomFieldChecks on Subject<CustomType> {
  // For field reads that will not get rejected, use `has`.
  Subject<Bar> get someField => has('someField', (a) => a.someField);
}
```

For expectations with custom predicates or failure descriptions, import
`package:checks/context.dart` to access the `context` getter on `Subject`. The
`Context` allows checking an expectation with `expect`, `expectAsync`, and
`expectUnawaited`, or extracting a derived value for performing other checks
with `nest` and `nestAsync`. Failures are reported by returning a `Rejection` or
an `Extracted.rejection`; extensions should avoid throwing exceptions.

Descriptions of the clause checked by `expect` or the label for `nest` are
passed as callbacks separately from the predicate or extractor. When there are
no failures the description callbacks are not called. When a condition is
described with `Condition.describe()` or `Condition.describeSync()`, the
description callbacks are called without running the predicates. Conditions can
also be checked against values without throwing a test failure using
`Condition.softCheck()` or `Condition.softCheckSync()`.

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
}
```
