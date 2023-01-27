# Trying Checks as a Preview

1.  Add a git dependency on this package:

    ```yaml
    dev_dependencies:
      checks:
        git:
          url: https://github.com/dart-lang/test
          path: pkgs/checks
          # Omit to try the latest, or pin to a commit to avoid
          # breaking changes while the library is experimental.
          ref: <sha>
    ```

1.  Add an import to `package:checks/checks.dart`.

1.  Replace the existing `package:test/test.dart` import with
    `package:test/scaffolding.dart`.

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
