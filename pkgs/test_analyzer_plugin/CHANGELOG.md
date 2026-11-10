## 0.1.0

- Initial release

- Available rules:
  - `test_in_test`: Report a warning when a `test`, `group`, `setUp`, `setUpAll`,
    `tearDown`, or `tearDownAll` is declared inside a `test`, `setUp`, `setUpAll`,
    `tearDown`, or `tearDownAll` declaration.

  - `non_nullable_is_not_null`: Report a warning when a non-nullable value is
    matched against `isNotNull` or `isNull`.

  - `use_contains_matcher`: Report a warning when an `expect` expectation of
    `true`, `false`, `isTrue`, or `isFalse` is paired with a `.contains` method
    call on an actual value (maybe wrapped with a `!`). Instead, the `contains`
    Matcher (maybe wrapped with the `isNot()` Matcher) should be used.

  - `use_is_empty_matcher`: Report a warning when an `expect` expectation of
    `true`, `false`, `isTrue`, or `isFalse` is paired with an `.isEmpty` or
    `.isNotEmpty` property access on an actual value. Instead, the `isEmpty` or
    `isNotEmpty` Matcher should be used.

  - `test_body_goes_last`: Report a lint when the body argument of a `test` or
    `group` is not last.

- Quick fixes
  - Offer a quick fix in the IDE for `test_in_test`.
