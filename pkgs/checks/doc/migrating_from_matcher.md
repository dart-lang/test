## Migrating from package:matcher

`package:checks` is currently in preview with an API expected to be close to its
stable `1.0.0` release. Once this package reaches `1.0.0`, it will be the Dart
team's recommended package to use for most tests.

[`package:matcher`][matcher] is the legacy package with an API exported from
`package:test/test.dart` and `package:test/expect.dart`.

[matcher]: https://pub.dev/packages/matcher

## FAQ

### Do I have to migrate all at once?

No! `package:checks` is designed to be a good neighbor with `package:matcher`.
`expect` and `check` share the same failure reporting and async lifecycle
mechanisms in `package:test`, so old tests can continue to use matchers while
new or updated tests use `checks`. Even a single `test()` body can mix `expect`
and `check` calls.

Adding `import 'package:checks/checks.dart';` alongside an existing
`import 'package:test/test.dart';` introduces no top-level name collisions.
Shared test utilities such as custom matchers also generally avoid conflicts
because `matcher` helpers are top-level functions or getters returning a
`Matcher`, whereas `checks` expectations are extension members on `Subject`.
You can add `Subject` extensions with the same names alongside existing custom
`Matcher` helpers and migrate both the utilities and their call sites
incrementally.

### _Should_ I migrate all at once?

For most existing projects, migrating incrementally gives the best return on
effort: write new tests with `package:checks`, and convert existing assertions
only in tests you are already editing or debugging.

The main benefits of `checks` (type-checked expectations, focused IDE
autocomplete, and composable syntax) pay off most when writing, updating, or
diagnosing tests. Rewriting stable, passing tests offers limited immediate
value while adding code review work, obscuring `git blame`, and requiring care
around a few [behavioral differences](#differences-in-behavior-from-matcher)
such as collection equality.

Teams that prefer a uniform assertion style across a test suite (whether
migrating by hand or with automated tooling) can migrate whole files or packages
at once and switch imports to `package:test/scaffolding.dart` to confirm no
`matcher` usage remains.

### Do I need to migrate at all?

No. `package:matcher` will continue to be published and supported, and there is
no deadline to migrate. When a future major version of `package:test` stops
re-exporting `matcher` from `package:test/test.dart`, existing tests will be
able to add a direct dependency on `package:matcher` and continue using
`expect` and matchers.

### Why is the Dart team adding a second framework?

The `matcher` package has a design which is fundamentally incompatible with
using static types to validate correct use. With an entirely new design, the
static types in `checks` give confidence that the expectation is appropriate for
the value, and narrow autocomplete choices in the IDE for a better editing
experience. The clean break from the legacy implementation and API also gives an
opportunity to make small behavior and signature changes to align with modern
Dart idioms.

### Should I start using checks right away?

Yes, if your package uses Dart 3.11 or later and you are comfortable with a
`0.x` preview `dev_dependency`. The API in `0.4.0` is expected to be close to
its `1.0.0` form while final feedback is gathered. Breaking changes remain
possible during the preview window (with `dart fix` support provided when
practical), and because `checks` is a `dev_dependency`, its version constraint
does not affect downstream consumers of published packages. Projects that
require strict stability guarantees can wait for `1.0.0`.

See some of the [improvements you can expect in
checks](#improvements-you-can-expect) below.

### What if I have custom `Matcher`s?

You do not need to rewrite existing custom `Matcher` subclasses upfront; keep
calling `expect` for them alongside `check` for as long as convenient. When you
do write custom expectations for `checks`, most helpers are short extension
methods on `Subject<YourType>` that compose `.has(...)` and existing checks
using only `package:checks/checks.dart`, without subclassing `Matcher` or
implementing mismatch descriptions. See [Writing custom
expectations](../README.md#writing-custom-expectations) for details.

### How can I be sure I have finished a migration?

The `matcher` APIs are exposed through `package:matcher/*`,
`package:test/test.dart`, and `package:test/expect.dart`. Once imports to those
libraries are removed or disallowed, no `matcher` expectations remain. Fully
migrated tests import `package:test/scaffolding.dart` and
`package:checks/checks.dart`.

One exception is callback verification helpers (`expectAsync0` through
`expectAsync6`, `expectAsyncUntil0` through `expectAsyncUntil6`, and
`neverCalled`), which are currently only exported from
`package:test/expect.dart`. Tests that need them can restrict that import with
`show` (for example, `import 'package:test/expect.dart' show expectAsync0;`) so
`expect` and matchers stay out of scope. Calls to `fail(message)` from
`expect.dart` can be replaced with `throw TestFailure(message)` from
`package:test/scaffolding.dart`.

## Adopting checks in a package

1.  Add a `dev_dependency` on `checks: ^0.4.0` (`dart pub add dev:checks`;
    requires Dart `^3.11.0`).

1.  Set up imports in the test file:
    -   **New test files or full-file migrations**: Import
        `package:test/scaffolding.dart` (instead of `package:test/test.dart`)
        and `package:checks/checks.dart`. Omitting `test.dart` keeps `matcher`'s
        top-level functions out of IDE autocomplete and surfaces analyzer errors
        on any remaining `expect` calls.
    -   **Incremental edits in an existing test file**: Add
        `package:checks/checks.dart` alongside `package:test/test.dart`, or
        import `package:test/scaffolding.dart` together with
        `package:test/expect.dart` until you are ready to remove `expect.dart`.

1.  Write or migrate test expectations using `check`.

## Migrating from Matchers

Conceptually, the two main building blocks of `package:matcher` map directly to
`package:checks`:

-   Top-level functions and getters returning a `Matcher` map to extension
    methods and getters on `Subject<T>`.
-   `Matcher` instances (objects passed to combinators, stored in variables or
    test tables, or accepted by test helper functions) map to `Condition<T>`
    instances.

At assertion call sites, replace `expect` or `expectLater` with `check` passing
the first argument, then call the corresponding extension member on the
returned `Subject`:

-   A bare non-matcher `expected` value becomes `.equals(expected)`, or
    `.deepEquals(expected)` when comparing collections by element (see below).
-   Zero-argument terminal matchers (such as `isEmpty`, `isNull`, `isTrue`,
    `isNaN`, or `emitsDone`) become **getters** on `Subject`.
-   Matchers that take arguments or extract a value for further checks (such as
    `completes`, `throws`, `returnsNormally`, `isNotNull`, `isA<T>`, or `emits`)
    become **methods** on `Subject`.
-   Nested `Matcher` arguments become `Condition` arguments written with the
    `.it()` dot shorthand.
-   `allOf(...)` becomes cascade syntax on the `Subject` (or `.which(.it()...)`
    on a nested property).

```dart
expect(actual, expected);
check(actual).equals(expected);
// or for collections:
check(actualCollection).deepEquals(expected);

expect(actualList, isEmpty);
check(actualList).isEmpty;

expect(actualList, everyElement(greaterThan(0)));
check(actualList).every(.it()..isGreaterThan(0));

await expectLater(actualFuture, completes);
await check(actualFuture).completes();
```

If you use the `reason` argument to `expect`, rename it to `because`.

```dart
expect(actual, isNotEmpty, reason: 'some explanation');
check(because: 'some explanation', actual).isNotEmpty;
```

Where tests previously stored a `Matcher` in a variable or passed a `Matcher`
into a helper function, use `Condition<T>`. Create a condition with `.it()` when
the type is inferred from context (such as a typed helper parameter) or
`Condition.it<T>()` otherwise. Combinators and expectation methods that extract
a derived subject (such as `isA`, `completes`, `throws`, and `emits`, though not
`has` or property getters) take a `Condition` argument, and conditions with
synchronous expectations can be applied to a `Subject<T>` with
`.which(condition)`:

```dart
// matcher:
void checkUser(String id, Matcher matcher) {
  expect(fetchUser(id), matcher);
}
checkUser('42', isA<User>().having((u) => u.name, 'name', 'Alice'));

// checks:
void checkUser(String id, Condition<User> condition) {
  check(fetchUser(id)).which(condition);
}
checkUser('42', .it()..has('name', (u) => u.name).equals('Alice'));
```

Conditions with asynchronous expectations can only be passed to asynchronous
expectations that accept a `Condition` (such as `completes`, `emits`, or
`inOrder`), not to `Subject.which` or other synchronous expectations.

### Differences in behavior from matcher

-   **Collection equality**: The `equals` Matcher performed a deep recursive
    equality check on collections. In `checks`, `.equals()` always uses
    `operator ==`, so collection comparisons typically need `.deepEquals()`
    instead of `.equals()`.
-   **Synchronous vs asynchronous `throws`**: In `matcher`, `throwsA` accepted
    synchronous callbacks, asynchronous callbacks returning a `Future`, and
    `Future` instances directly. In `checks`, `Subject<T Function()>.throws()`
    only checks for synchronous throws and fails if the callback returns a
    `Future`. For asynchronous code, invoke the function and check the returned
    `Future`:
    ```dart
    check(() => syncOperation()).throws<StateError>();
    await check(asyncOperation()).throws<StateError>();
    ```
-   **Streams and `StreamQueue`**: Streams must be wrapped into a `StreamQueue`
    (from `package:async/async.dart`) before checking events. Use
    `check(actualStream).withQueue` when checking a stream once, or construct
    `StreamQueue(actualStream)` explicitly when checking a single-subscription
    stream across multiple statements. `emitsAnyOf` is
    `Subject<StreamQueue>.anyOf` and `emitsInOrder` is `inOrder`; both take an
    `Iterable<Condition<StreamQueue<T>>>` matching behavior on the queue rather
    than bare values or element matchers. Use
    `.it()..emits(.it()..equals(expected))` to check emitted elements.
-   **`matches` vs `matchesPattern`**: In `package:matcher`, the [`matches`
    Matcher][matches] converted a `String` argument into a `RegExp`, so
    `matches(r'\d')` matched `'1'`. Even though `String` implements `Pattern`,
    it was not matched as a literal `String` pattern. With `matchesPattern`, a
    `String` argument is used directly as a `Pattern` via
    [`Pattern.allMatches`][allMatches]. To preserve regular expression matching,
    change `matches(regexString)` to `matchesPattern(RegExp(regexString))`.
-   **`TypeMatcher.having` vs `.has`**: `TypeMatcher.having` is replaced by the
    more general `.has`, which works on any `Subject` rather than only after
    `.isA<T>()`. Note the argument order change: `.has('name', (v) => v.field)`
    takes the property name *first* and the extractor callback *second*, and
    returns a `Subject` for the extracted field instead of taking a trailing
    matcher argument:
    ```dart
    expect(actual, isA<Foo>().having((f) => f.bar, 'bar', equals(1)));
    check(actual).isA<Foo>().has('bar', (f) => f.bar).equals(1);
    ```
-   **Static receiver types**: Matchers such as `isTrue`/`isFalse` accepted
    `Object?`, and `contains` dynamically dispatched across `String`, `Iterable`
    (matching either an element or a `Matcher`), and `Map`. In `checks`,
    `isTrue` and `isFalse` require `Subject<bool>`, and `contains` is typed per
    receiver: `Subject<String>.contains(Pattern)`,
    `Subject<Iterable<T>>.contains(T)` for an element (or `.any(Condition<T>)`
    for a condition), and `Subject<Map<K, V>>.containsKey(K)` or
    `.containsValue(V)`.

[matches]: https://pub.dev/documentation/matcher/latest/matcher/matches.html
[allMatches]: https://api.dart.dev/stable/dart-core/Pattern/allMatches.html

### Matchers with replacements under a different name

-   `allOf` -> cascade syntax (`check(x)..a()..b()`) or
    `.which(.it()..a()..b())`
-   `anyElement` -> `Subject<Iterable>.any`
-   `closeTo(value, delta)` -> `Subject<num>.isCloseTo(value, delta)`
-   `completion(Matcher)` -> `Subject<Future>.completes([condition])`
-   `contains(Matcher)` on `Iterable` -> `Subject<Iterable>.any(condition)`
    (use `.contains(element)` for `==` equality; on `Map`, use
    `.containsKey(key)` or `.containsValue(value)`)
-   `containsAllInOrder(iterable)` ->
    `Subject<Iterable>.containsEqualInOrder(iterable)` to compare elements with
    `==`, or `Subject<Iterable>.containsMatchingInOrder(conditions)` to check
    conditions other than equality
-   `containsPair(key, value)` -> `Subject<Map>[key].equals(value)`
-   `emitsAnyOf` -> `Subject<StreamQueue>.anyOf`
-   `emitsDone` -> `Subject<StreamQueue>.isDone`
-   `emitsInOrder` -> `Subject<StreamQueue>.inOrder`
-   `everyElement` -> `Subject<Iterable>.every`
-   `greaterThan`, `greaterThanOrEqualTo`, `lessThan`, `lessThanOrEqualTo` ->
    `isGreaterThan`, `isGreaterOrEqual`, `isLessThan`, `isLessOrEqual`
-   `hasLength(expected)` -> `length.equals(expected)`
-   `isNot(Matcher)` -> `not(condition)` (or `isNotA<T>()` for negated type
    checks)
-   `matches(RegExp)` -> `Subject<String>.matchesPattern(RegExp(...))`
-   `pairwiseCompare` -> `Subject<Iterable>.pairwiseMatches`
-   `prints` -> `Subject<void Function()>.prints()` (or
    `Subject<Future<void> Function()>.prints()`) to check expectations on
    captured output, e.g. `check(fn).prints().equals(expected)` or
    `await check(asyncFn).prints(.it()..equals(expected))`
-   `same` -> `identicalTo`
-   `stringContainsInOrder` -> `Subject<String>.containsInOrder`
-   `throwsA(Matcher)` -> `Subject<T Function()>.throws<E>([condition])` for
    synchronous callbacks, or `Subject<Future>.throws<E>([condition])` for
    futures

### Members from `package:test/expect.dart` without a direct replacement

-   Type-specific matchers: `checks` does not ship named matchers for individual
    types. Instead of `isArgumentError` or `isList`, use `isA<ArgumentError>()`
    or `isA<List>()`, and similarly `throws<ArgumentError>()` over
    `throwsArgumentError`.
-   `anything`: When a condition is needed that accepts any value, pass `.it()`.
    Typically a condition argument can be omitted instead.
-   Sign and zero comparisons (`isPositive`, `isNonPositive`, `isZero`,
    `isNonZero`, `isNonNegative`): Use `isGreaterThan(0)`, `isLessOrEqual(0)`,
    `equals(0)`, `not(.it()..equals(0))`, and `isGreaterOrEqual(0)`.
    (`Subject<num>` does provide `isNegative` and `isNotNegative` getters, which
    delegate to `num.isNegative` and therefore treat `-0.0` as negative.)
-   Numeric range comparisons (`inClosedOpenRange`, `inExclusiveRange`,
    `inInclusiveRange`, `inOpenClosedRange`): Chain both bounds onto the same
    subject with cascades (for example,
    `check(n)..isGreaterOrEqual(min)..isLessThan(max)`).
-   `isIn(collection)`: Invert the check and test the collection instead, for
    example `check(collection).contains(actual)`.
-   `predicate(fn, description)`: Extract a boolean with
    `.has(description, fn).isTrue` for one-off checks, or write a custom
    extension method using `package:checks/context.dart` for reusable checks.
-   `orderedEquals`: Use `deepEquals`. In the unusual case where nested
    collections need shallow `operator ==` comparison instead of deep equality,
    wrap each expected element in a condition:
    `.deepEquals(expected.map((e) => Condition.it<Object?>()..equals(e)))`.
-   `containsAll` (unordered subset allowing extra elements), `containsOnce`,
    and `emitsInAnyOrder`: No built-in single-call equivalent yet. Keep `expect`
    where needed, or for `containsOnce` filter the iterable first
    (`check(items.where((e) => e == target)).length.equals(1)`).
-   `expectAsync0` through `expectAsync6`, `expectAsyncUntil0` through
    `expectAsyncUntil6`, and `neverCalled`: Continue to import
    `package:test/expect.dart` (optionally restricted with `show`) for these
    callback helpers.
-   `fail(message)`: Replace with `throw TestFailure(message)` (exported from
    `package:test/scaffolding.dart`).

## Improvements you can expect

Expectations are statically restricted to those which are appropriate for the
type. While the following is statically allowed with `matcher` and only fails at
runtime, it cannot be written at all with `checks`:

```dart
expect(1, contains(1)); // No static error, always fails
check(1).contains(1); // Static error: The method 'contains' isn't defined
```

These static restrictions also improve the relevance of IDE autocomplete
suggestions. While editing with the cursor at `_`, the suggestions provided in
the `matcher` example can include _any_ top-level element including matchers
for unrelated types, type names, and top-level definitions from other packages.
With the cursor following `.` in the `checks` example, suggestions are narrowed
to expectations and utilities appropriate for the subject's type.

```dart
expect(actual, _ // many unrelated suggestions
check(actual)._ // specific suggestions
```

Asynchronous matchers in `matcher` are a subtype of synchronous matchers, even
though they do not satisfy the same behavior contract. Some APIs accepting a
matcher cannot validate whether an asynchronous matcher works in that context,
which can result in false successes, false failures, or misleading errors. In
`checks`, asynchronous expectations are rejected explicitly at runtime when a
synchronous condition is required, with an error pointing directly to the
misuse.

There is also no split between `expect` and `expectLater`. In `matcher`, passing
an asynchronous matcher to `expect` instead of `await expectLater` compiled
without warning and could fail out of band. In `checks`, asynchronous
expectations return a `Future` directly from `check(...)` so they can be awaited
naturally when ordering or extracted values matter, while also holding the test
open until they complete (annotated with `@awaitNotRequired` so fire-and-forget
checks remain lint-clean when ordering does not matter).

Finally, composed checks produce structured failure diagnostics automatically.
Cascades, `.has(...)` extractions, and nested `.it()` conditions report which
prior clauses on the subject already passed and pinpoint the failing nested
property, reducing the need to write manual `because:` descriptions.
