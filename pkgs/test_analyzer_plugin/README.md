# test_analyzer_plugin

This package is an analyzer plugin that provides additional static analysis for
usage of the test package.

This analyzer plugin provides the following additional analysis:

* Report a warning when a `test` or a `group` is declared inside a `test`
  declaration. This can _sometimes_ be detected at runtime. This warning is
  reported statically.

* Offer a quick fix in the IDE for the above warning, which moves the violating
  `test` or `group` declaration below the containing `test` declaration.