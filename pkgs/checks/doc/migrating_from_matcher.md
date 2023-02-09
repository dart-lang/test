## Migrating from package:matcher

`package:checks` is currently in preview. Once this package reaches a stable
version, it will be the recommended package by the Dart team to use for most
tests.

**Do I have to migrate all at once?** No. `package:matcher` will be compatible
with `package:checks`, and old tests can continue to use matchers. Test cases
within the same file can use a mix of `expect` and `check`.

**Do I need to migrate right away?** No. When `package:test`stops exporting
these members it will be possible to add a dependency on `package:matcher` and
continue to use them. `package:matcher` will get deprecated and will not see new
development, but the existing features will continue to work.

**Why is the Dart team moving away from matcher?** The `matcher` package has a
design which is fundamentally incompatible with using static types to validate
correct use. With an entirely new design, the static types in `checks` give
confidence that the expectation is appropriate for the value, and can narrow
autocomplete choices in the IDE for a better editing experience. The clean break
from the legacy implementation and API also gives an opportunity to make small
behavior and signature changes to align with modern Dart idioms.

**Should I start using checks over matcher for new tests?** There is still a
high potential for minor or major breaking changes during the preview window.
Once this package is stable, yes! The experience of using `checks` improves on
`matcher`.

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

Replace calls to `expect` with a call to `check` passing the first argument.
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
    The arguments are `Condition<StreamQueue>` and match a behavior of the
    entire stream. In `matcher` the elements to expect could have been a bare
    value to check for equality, a matcher for the emitted value, or a matcher
    for the entire queue which would match multiple values. Use `it()..emits()`
    to check the emitted elements.
-   In `package:matcher` the [`matches` Matcher][matches] converted a `String`
    argument into a `Regex`, so `matches(r'\d')` would match the value `'1'`.
    This was potentially confusing, because even though `String` is a subtype of
    `Pattern`, it wasn't used as a pattern directly.
    With `matchesPattern` a `String` argument is used as a `Pattern` and
    comparison uses [`String.allMatches`][allMatches].
    For backwards compatibility change `matches(regexString)` to
    `matchesPattern(RegExp(regexString))`.

[matches]:https://pub.dev/documentation/matcher/latest/matcher/Matcher/matches.html
[allMatches]:https://api.dart.dev/stable/2.19.1/dart-core/Pattern/allMatches.html

### Matchers with replacements under a different name

-   `anyElement` -> `Subject<Iterable>.any`
-   `everyElement` -> `Subject<Iterable>.every`
-   `completion(Matcher)` -> `completes(Condition)`
-   `containsPair(key, value)` -> Use `Subject<Map>[key].equals(value)`
-   `hasLength(expected)` -> `length.equals(expected)`
-   `isNot(Matcher)` -> `not(Condition)`
-   `pairwiseCompare` -> `pairwiseComparesTo`
-   `same` -> `identicalTo`
-   `stringContainsInOrder` -> `Subject<String>.containsInOrder`

### Members from `package:test/expect.dart` without a direct replacement

-   `checks` does not ship with any type checking matchers for specific types.
    Instead of, for example,  `isArgumentError` use `isA<ArgumentError>`, and
    similary `throws<ArgumentError>` over `throwsArgumentError`.
-   `anything`. When a `Condition` is needed that should accept any value, pass
    `it()` without cascading any expectation checks.
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
    with `check(actual).deepEquals(expected.map((e) => it()..equals(e)))`;
-   `prints`: TODO add missing expectation? Is this one worth replacing?
-   `predicate`: TODO add missing expectation
