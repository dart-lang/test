# test_analyzer_plugin

This package is an analyzer plugin that provides additional static analysis for
usage of the test package.

This analyzer plugin provides the following additional analysis:

* Report a warning when a `test`, `group`, `setUp`, `setUpAll`, `tearDown`, or
  `tearDownAll` is declared inside a `test`, `setUp`, `setUpAll`, `tearDown`, or
  `tearDownAll` declaration. This can _sometimes_ be detected at runtime, but
  it's more convenient to report this warning statically.

* Report a warning when a non-nullable value is matched against `isNotNull` or
  `isNull`.

* Report a warning when an `expect` expectation of `true`, `false`, `isTrue`, or
  `isFalse` is paired with a `.contains` method call on an actual value (maybe
  wrapped with a `!`). Instead, the `contains` Matcher (maybe wrapped with the
  `isNot()` Matcher) should be used. This Matcher yields meaningful failure
  messages.

* Report a warning when an `expect` expectation of `true`, `false`, `isTrue`,
  or `isFalse` is paired with an `.isEmpty` or `.isNotEmpty` property access on
  an actual value. Instead, the `isEmpty` or `isNotEmpty` Matcher should be
  used. These Matchers yield meaningful failure messages.

* Report a lint when the body argument of a `test` or `group` is not last. Lint
  rules are not enabled by default and must be actively enabled in analysis
  options.

* Offer a quick fix in the IDE for the above warning, which moves the violating
  `test` or `group` declaration below the containing `test` declaration.
