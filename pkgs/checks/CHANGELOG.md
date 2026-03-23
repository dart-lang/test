## 0.3.2-wip

- Require Dart 3.7
- Improve speed of pretty printing for large collections.

## 0.3.1

-   Directly compare keys across actual and expected `Map` instances when
    checking deep collection equality and all the keys can be directly compared
    for equality. This maintains the path into a nested collection for typical
    cases of checking for equality against a purely value collection.
-   Always wrap Condition descriptions in angle brackets.
-   Add `containsMatchingInOrder` and `containsEqualInOrder` to replace the
    combined functionality in `containsInOrder`.
-   Replace `pairwiseComparesTo` with `pairwiseMatches`.
-   Fix a bug where printing the result of a failed deep quality check would
    fail with a `TypeError` when comparing large `Map` instances.
-   Increase SDK constraint to ^3.5.0.
-   Clarify this package is experimental.

## 0.3.0

-   **Breaking Changes**
    -   Remove the `Condition` class and the `it()` utility. Replace calls to
        `(it()..someExpectation())` with `((it) => it.someExpectation())`.
-   Add class modifiers to restrict extension of implementation classes.

## 0.2.2

-   Return the first failure from `softCheck` and `softCheckAsync` as
    documented, instead of the last failure when there are multiple failures.
-   Add example `because` usage and mention the "reason" name in the migration
    guide.
-   Add `ComparableChecks` with comparison expectations for subject types that
    implement `Comparable`.

## 0.2.1

-   Add a link to file issues with feedback in the README.

## 0.2.0

-   **Breaking Changes**
    -   `checkThat` renamed to `check`.
    -   `nest` and `nestAsync` take `Iterable<String> Function()` arguments for
        `label` instead of `String`.
    -   Async expectation extensions `completes`, `throws`, `emits`, and
        `emitsError` no longer return a `Future<Subject>`. Instead they take an
        optional `Condition` argument which can check expectations that would
        have been checked on the returned subject.
    -   `nestAsync` no longer returns a `Subject`, callers must pass the
        followup `Condition` to the nullable argument.
    -   Remove the `which` extension on `Future<Subject>`.
    -   `matches` renamed to `matchesPattern` and now accepts a `Pattern`
        argument, instead of limiting to `RegExp`.
-   Added an example.
-   Include a stack trace in the failure description for unexpected errors from
    Futures or Streams.

## 0.1.0

-   Initial release.
