## Migrating from package:matcher

`package:checks` is currently in preview. Once this package reaches a stable
version, it will be the recommended package by the Dart team to use for most
tests.

[`package:matcher`][matcher] is the legacy package with an API exported from
`package:test/test.dart` and `package:test/expect.dart`. 

**Do I have to migrate all at once?** No. `package:matcher` will be compatible
with `package:checks`, and old tests can continue to use matchers. Test cases
within the same file can use a mix of `expect` and `check`.

**_Should_ I migrate all at once?** Probably not, it depends on your tolerance
for having tests use a mix of APIs. As you add new tests, or need to make
updates to existing tests, using `checks` will make testing easier. Tests which
are stable and passing will not get significant benefits from a migration.

**Do I need to migrate at all?** No. When `package:test`stops exporting
these members it will be possible to add a dependency on `package:matcher` and
continue to use them. `package:matcher` will continue to be available.

**Why is the Dart team adding a second framework?** The `matcher` package has a
design which is fundamentally incompatible with using static types to validate
correct use. With an entirely new design, the static types in `checks` give
confidence that the expectation is appropriate for the value, and can narrow
autocomplete choices in the IDE for a better editing experience. The clean break
from the legacy implementation and API also gives an opportunity to make small
behavior and signature changes to align with modern Dart idioms.

**Should I start using checks right away?** There is still a
high potential for minor or major breaking changes during the preview window.
Once this package is stable, yes! The experience of using `checks` improves on
`matcher`. See some of the [improvements to look forward to in checks
below](#improvements-you-can-expect).

[matcher]: https://pub.dev/packages/matcher

## Trying Checks as a Preview

1.  Add a `dev_dependency` on `checks: ^0.2.0`.

1.  Replace the existing `package:test/test.dart` import with
    `package:test/scaffolding.dart`.

1.  Add an import to `package:checks/checks.dart`.

1.  For an incremental migration within the test, add an import to
    `package:test/expect.dart`. Remove it to surface errors in tests that still
    need to be migrated, or keep it in so the tests work without being fully
    migrated.

1.  Migrate the test cases.

## Migrating from Matchers

Replace calls to `expect` or `expectLater` with a call to `check` passing the
first argument.
When a direct replacement is available, change the second argument from calling
a function returning a Matcher, to calling the relevant extension method on the
`Subject`.

Whenever you see a bare non-matcher value argument for `expected`, assume it
should use the `equals` expectation, although take care when the subject is a
collection.
See below, `.equals` may not always be the correct replacement in
`package:checks`.

```dart
expect(actual, expected);
check(actual).equals(expected);
// or maybe
check(actualCollection).deepEquals(expected);

await expectLater(actual, completes());
await check(actual).completes();
```

If you use the `reason` argument to `expect`, rename it to `because`.

```dart
expect(actual, expectation(), reason: 'some explanation');
check(because: 'some explanation', actual).expectation();
```

### Differences in behavior from matcher

-   The `equals` Matcher performed a deep equality check on collections.
    `.equals()` expectation will only correspond to [operator ==] so some tests
    may need to replace `.equals()` with `.deepEquals()`.
-   Streams must be explicitly wrapped into a `StreamQueue` before they can be
    tested for behavior. Use `check(actualStream).withQueue`.
-   `emitsAnyOf` is `Subject<StreamQueue>.anyOf`. `emitsInOrder` is `inOrder`.
    The arguments are `FutureOr<void> Function(Subject<StreamQueue>)` and match
    a behavior of the entire stream. In `matcher` the elements to expect could
    have been a bare value to check for equality, a matcher for the emitted
    value, or a matcher for the entire queue which would match multiple values.
    Use `(s) => s.emits((e) => e.interestingCheck())` to check the emitted
    elements.
-   In `package:matcher` the [`matches` Matcher][matches] converted a `String`
    argument into a `Regex`, so `matches(r'\d')` would match the value `'1'`.
    This was potentially confusing, because even though `String` is a subtype of
    `Pattern`, it wasn't used as a pattern directly.
    With `matchesPattern` a `String` argument is used as a `Pattern` and
    comparison uses [`String.allMatches`][allMatches].
    For backwards compatibility change `matches(regexString)` to
    `matchesPattern(RegExp(regexString))`.
-   The `TypeMatcher.having` API is replace by the more general`.has`. While
    `.having` could only be called on a `TypeMatcher` using `.isA`, `.has` works
    on any `Subject`. `CoreChecks.has` takes 1 fewer arguments - instead of
    taking the last argument, a `matcher` to apply to the field, it returns a
    `Subject` for the field.

[matches]:https://pub.dev/documentation/matcher/latest/matcher/Matcher/matches.html
[allMatches]:https://api.dart.dev/stable/2.19.1/dart-core/Pattern/allMatches.html

### Matchers with replacements under a different name

-   `anyElement` -> `Subject<Iterable>.any`
-   `everyElement` -> `Subject<Iterable>.every`
-   `completion(Matcher)` -> `completes(conditionCallback)`
-   `containsPair(key, value)` -> Use `Subject<Map>[key].equals(value)`
-   `hasLength(expected)` -> `length.equals(expected)`
-   `isNot(Matcher)` -> `not(conditionCallback)`
-   `pairwiseCompare` -> `pairwiseComparesTo`
-   `same` -> `identicalTo`
-   `stringContainsInOrder` -> `Subject<String>.containsInOrder`

### Members from `package:test/expect.dart` without a direct replacement

-   `checks` does not ship with any type checking matchers for specific types.
    Instead of, for example,  `isArgumentError` use `isA<ArgumentError>`, and
    similary `throws<ArgumentError>` over `throwsArgumentError`.
-   `anything`. When a condition callback is needed that should accept any
    value, pass `(_) {}`.
-   Specific numeric comparison - `isNegative`, `isPositive`, `isZero` and their
    inverses. Use `isLessThan`, `isGreaterThan`, `isLessOrEqual`, and
    `isGreaterOrEqual` with appropriate numeric arguments.
-   Numeric range comparison, `inClosedOpenRange`, `inExclusiveRange`,
    `inInclusiveRange`, `inOpenClosedRange`. Use cascades to chain a check for
    both ends of the range onto the same subject.
-   `containsOnce`: TODO add missing expectation
-   `emitsInAnyOrder`: TODO add missing expectation
-   `expectAsync` and `expectAsyncUntil`. Continue to import
    `package:test/expect.dart` for these APIs.
-   `isIn`: TODO add missing expectation
-   `orderedEquals`: Use `deepEquals`. If the equality needs to specifically
    *not* be deep equality (this is unusual, nested collections are unlikely to
    have a meaningful equality), force using `operator ==` at the first level
    with `.deepEquals(expected.map((e) => (Subject<Object?> s) => s.equals(e)))`;
-   `prints`: TODO add missing expectation? Is this one worth replacing?
-   `predicate`: TODO add missing expectation

## Improvements you can expect

Expectations are statically restricted to those which are appropriate for the
type. So while the following is statically allowed with `matcher` but always
fails at runtime, the expectation cannot be written at all with `checks`.

```dart
expect(1, contains(1)); // No static error, always fails
check(1).contains(1); // Static error. The method 'contains' isn't defined
```

These static restrictions also improve the relevance of IDE autocomplete
suggestions. While editing with the cursor at `_`, the suggestions provided
in the `matcher` example can include _any_ top level element including matchers
appropriate for other types of value, type names, and top level definitions from
other packages. With the cursor following a `.` in the `checks` example the
suggestions will only be expectations or utilities appropriate for the value
type.

```dart
expect(actual, _ // many unrelated suggestions
check(actual)._ // specific suggestions
```

Asynchronous matchers in `matcher` are a subtype of synchronous matchers, but do
not satisfy the same behavior contract. Some APIs which use a matcher could not
validate whether it would satisfy the behavior it needs, and it could result in
a false success, false failure, or misleading errors. APIs which correctly use
asynchronous matchers need to do a type check and change their interaction based
on the runtime type. Asynchronous expectations in `checks` are refused at
runtime when a synchronous answer is required. The error will help solve the
specific misuse, instead of resulting in a confusing error, or worse a missed
failure. The reason for the poor compatibility in `matcher` is due to some
history of implementation - asynchronous matchers were written in `test`
alongside `expect`, and synchronous matchers have no dependency on the
asynchronous implementation.

Asynchronous expectations always return a `Future`, and with the
[`unawaited_futures` lint][unawaited lint] should more safely ensure that
asynchronous expectation work is completed within the test body. With `matcher`
it was up to the author to correctly use `await expecLater` for asynchronous
cases, and `expect` for synchronous cases, and if `expect` was used with an
asynchronous matcher the expectation could fail at any point.

[unawaited lint]: https://dart.dev/lints/unawaited_futures
