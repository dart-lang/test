[![Dart CI](https://github.com/dart-lang/test/actions/workflows/dart.yml/badge.svg)](https://github.com/dart-lang/test/actions/workflows/dart.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/dart-lang/test/badge)](https://deps.dev/project/github/dart-lang%2Ftest)

## What's here?

Welcome! [package:test](pkgs/test/) is the standard testing library for Dart and
Flutter. If you have questions about Dart testing, please see the docs for
[package:test](pkgs/test/). `package:test_api` and `package:test_core`
are implementation details and generally not user-facing.

[package:checks](pkgs/checks/) is a relatively new library for expressing test
expectations. It's a more modern version of `package:matcher` and features a
literate API.

## Packages

| Package | Description | Issues | Version |
| --- | --- | --- | --- |
| [checks](pkgs/checks/) | A framework for checking values against expectations and building custom expectations. | [![issues](https://img.shields.io/badge/issues-4774bc)][checks_issues] | [![pub package](https://img.shields.io/pub/v/checks.svg)](https://pub.dev/packages/checks) |
| [fake_async](pkgs/fake_async/) | Fake asynchronous events such as timers and microtasks for deterministic testing. | [![issues](https://img.shields.io/badge/issues-4774bc)][fake_async_issues] | [![pub package](https://img.shields.io/pub/v/fake_async.svg)](https://pub.dev/packages/fake_async) |
| [matcher](pkgs/matcher/) | Support for specifying test expectations via an extensible Matcher class. Also includes a number of built-in Matcher implementations for common cases. | [![issues](https://img.shields.io/badge/issues-4774bc)][matcher_issues] | [![pub package](https://img.shields.io/pub/v/matcher.svg)](https://pub.dev/packages/matcher) |
| [test](pkgs/test/) | A full featured library for writing and running Dart tests across platforms. | [![issues](https://img.shields.io/badge/issues-4774bc)][test_issues] | [![pub package](https://img.shields.io/pub/v/test.svg)](https://pub.dev/packages/test) |
| [test_api](pkgs/test_api/) | The user facing API for structuring Dart tests and checking expectations. | | [![pub package](https://img.shields.io/pub/v/test_api.svg)](https://pub.dev/packages/test_api) |
| [test_core](pkgs/test_core/) | A basic library for writing tests and running them on the VM. | | [![pub package](https://img.shields.io/pub/v/test_core.svg)](https://pub.dev/packages/test_core) |
| [test_descriptor](pkgs/test_descriptor/) | An API for defining and verifying files and directory structures. | [![issues](https://img.shields.io/badge/issues-4774bc)][test_descriptor_issues] | [![pub package](https://img.shields.io/pub/v/test_descriptor.svg)](https://pub.dev/packages/test_descriptor) |
| [test_process](pkgs/test_process/) | Test processes: starting; validating stdout and stderr; checking exit code. | [![issues](https://img.shields.io/badge/issues-4774bc)][test_process_issues] | [![pub package](https://img.shields.io/pub/v/test_process.svg)](https://pub.dev/packages/test_process) |

[checks_issues]: https://github.com/dart-lang/test/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Achecks
[fake_async_issues]: https://github.com/dart-lang/test/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Afake_async
[matcher_issues]: https://github.com/dart-lang/test/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Amatcher
[test_issues]: https://github.com/dart-lang/test/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Atest
[test_descriptor_issues]: https://github.com/dart-lang/test/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Atest_descriptor
[test_process_issues]: https://github.com/dart-lang/test/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Atest_process
