## 0.7.8-wip

* Restrict to latest version of analyzer package.
- Require Dart 3.7

## 0.7.7

* Expand pub constraint to allow the latest `analyzer`.

## 0.7.6

* Fix an assertion failure when using `setUpAll` or `tearDownAll` and running
  with asserts enabled.

## 0.7.5

* `test()` and `group()` functions now take an optional `TestLocation` that will
  be used as the location of the test in JSON reporters instead of being parsed
  from the call stack.

## 0.7.4

* Allow `analyzer: '>=6.0.0 <8.0.0'`
* Increase SDK constraint to ^3.5.0.
* Support running Node.js tests compiled with dart2wasm.

## 0.7.3

* Increase SDK constraint to ^3.4.0.

## 0.7.2

* Update min SDK constraint to 3.2.0.

## 0.7.1

- Added [`@doNotSubmit`](https://pub.dev/documentation/meta/latest/meta/doNotSubmit-constant.html) to `test(solo: ...)` and `group(solo: ...)`. In
  practice, this means that code that was relying on ignoring deprecation
  warnings and using `solo` or `group` with a `skip` parameter will now fail if
  `dart analyze --fatal-infos` (or similar) is enabled.

## 0.7.0

- Deprecate `Runtime.internetExplorer`.
- Added `dart2wasm` as a supported compiler for the `chrome` runtime.
- **BREAKING**: Removed the `experimentalChromeWasm` runtime.
- **BREAKING**: Removed `Runtime.isJS` and `Runtime.isWasm`, as this is now
  based on the compiler and not the runtime.

## 0.6.1

- Drop support for null unsafe Dart, bump SDK constraint to `3.0.0`.
- Make some implementation classes `final`. These classes were never intended to
  be extended or implemented. `Metadata`, `PlatformSelector`, `RemoteListener`,
  `Runtime`, `StackTraceFormatter`, `SuitePlatform`, `RemoteException`,
  `TestHandle`, `OutstandingWork`, `OutsideTestException`, `OnPlatform`,
  `Retry`, `Skip`, `Tags`, `TestOn`, `Timeout`.
- Mark an implementation class `interface`: `StackTraceMapper`.
- Change the `Compiler` class into an `enum`.
- Make `Fake` a `mixin class`.
- Allow the latest analyzer (6.x.x).

## 0.6.0

- Remove the `package:test_api/expect.dart' library. `test`will export from`package:matcher` directly.
- Fix compatibility with wasm number semantics.

## 0.5.2

- Remove deprecation for the `scaffolding.dart` and `backend.dart` libraries.
- Export `registerException` from the `scaffolding.dart` library.

## 0.5.1

- Handle a missing `'compiler'` value when running a test compiled against a
  newer `test_api` than the runner back end is using. The expectation was that
  the json protocol is only used across packages compatible with the same major
  version of the `test_api` package, but `flutter test` does not check the
  version of packages in the pub solve for user test code.

## 0.5.0

- Add `Compiler` class, exposed through `backend.dart`.
- Support compiler identifiers in platform selectors.
- Add `compiler` field to `SuitePlatform`. This will become required in the next
  major release.
- **BREAKING** Add required `defaultCompiler` and `supportedCompilers` fields
  to `Runtime`.
- Add `package:test_api/hooks_testing.dart` library for writing tests against
  code that uses `package:test_api/hooks.dart`.
- **BREAKING** Remove `ErrorFormatter`, `expectAsync`, `throws`, and `Throws`
  from `package:test_api/test_api.dart`.

## 0.4.18

- Don't run `tearDown` until the test body and outstanding work is complete,
  even if the test has already failed.

## 0.4.17

- Deprecate `throwsNullThrownError`, use `throwsA(isA<TypeError>())` instead.
  The implementation has been changed to ease migrations.
- Deprecate `throwsCyclicInitializationError` and replace the implementation
  with `Throws(TypeMatcher<Error>())`. The specific exception no longer exists
  and there is no guarantee about what type of error will be thrown.

## 0.4.16

- Add the `experimental-chrome-wasm` runtime. This is very unstable and will
  eventually be deleted, to be replaced by a `--compiler` flag. See
  https://github.com/dart-lang/test/issues/1776 for more information on future
  plans
- Add `isWasm` field to `Runtime` (defaults to `false`).

## 0.4.15

- Expand the pubspec description.
- Support `package:matcher` version `0.12.13`.

## 0.4.14

- Require Dart >= 2.18.0
- Support the latest `package:analyzer`.

## 0.4.13

- Fix `printOnFailure` output to be associated with the correct test.

## 0.4.12

- Internal cleanup.

## 0.4.11

- Support the latest version of `package:matcher`.

## 0.4.10

- Add `Target` to restrict `TestOn` annotation to library level.

## 0.4.9

- Add `ignoreTimeouts` option to `Suite`, which disables all timeouts for all
  tests in that suite.

## 0.4.8

- `TestFailure` implements `Exception` for compatibility with
  `only_throw_exceptions`.

## 0.4.7

- Remove logging about enabling the chain-stack-traces flag from the invoker.

## 0.4.6

- Give a better exception when using `markTestSkipped` outside of a test.
- Format stack traces if a formatter is available when serializing tests
  and groups from the remote listener.

## 0.4.5

- Add defaulting for older test backends that don't pass a configuration for
  the `allow_duplicate_test_names` parameter to the remote listener.

## 0.4.4

- Allow disabling duplicate test or group names in the `Declarer`.

## 0.4.3

- Use the latest `package:matcher`.

## 0.4.2

- Update `analyzer` constraint to `>=1.5.0 <3.0.0`.

## 0.4.1

- Give a better error when `printOnFailure` is called from outside a test
  zone.

## 0.4.0

- Add libraries `scaffolding.dart`, and `expect.dart` to allow importing as
  subset of the normal surface area.
- Add new APIs in `hooks.dart` to allow writing custom expectation frameworks
  which integrate with the test runner.
- Add examples to `throwsA` and make top-level `throws...` matchers refer to it.
- Disable stack trace chaining by default.
- Fix `expectAsync` function type checks.
- Add `RemoteException`, `RemoteListener`, `StackTraceFormatter`, and
  `StackTraceMapper` to `backend.dart`.
- **Breaking** remove `Runtime.phantomJS`
- **Breaking** Add callback to get the suite channel in the `beforeLoad`
  callback of `RemoteListener.start`. This is now used in place of using zones
  to communicate the value.

## 0.3.0

- **Breaking** `TestException.message` is now nullable.
  - Fixes handling of `null` messages in remote exceptions.

## 0.2.20

- Fix some strong null safety mode errors in the original migration.

## 0.2.19

- Stable release for null safety.

## 0.2.19-nullsafety.7

- Expand upper bound constraints for some null safe migrated packages.

## 0.2.19-nullsafety.6

- Fix `spawnHybridUri` to respect language versioning of the spawned uri.

## 0.2.19-nullsafety.5

- Update SDK constraints to `>=2.12.0-0 <3.0.0` based on beta release
  guidelines.

## 0.2.19-nullsafety.4

- Allow prerelease versions of the 2.12 sdk.

## 0.2.19-nullsafety.3

- Add capability to filter to a single exact test name in `Declarer`.
- Add `markTestSkipped` API.

## 0.2.19-nullsafety.2

- Allow `2.10` stable and `2.11.0-dev` SDKs.
- Annotate the classes used as annotations to restrict their usage to library
  level.

## 0.2.19-nullsafety

- Migrate to NNBD.
  - The vast majority of changes are intended to express the pre-existing
    behavior of the code regarding to handling of nulls.
  - **Breaking Change**: `GroupEntry.name` is no longer nullable, the root
    group now has the empty string as its name.
- Add the `Fake` class, available through `package:test_api/fake.dart`. This
  was previously part of the Mockito package, but with null safety it is useful
  enough that we decided to make it available through `package:test`. In a
  future release it will be made available directly through
  `package:test_api/test_api.dart` (and hence through
  `package:test_core/test_core.dart` and `package:test/test.dart`).

## 0.2.18+1 (Backport)

- Fix `spawnHybridUri` to respect language versioning of the spawned uri.

## 0.2.18

- Update to `matcher` version `0.12.9`.

## 0.2.17

- Add `languageVersionComment` on the `MetaData` class. This should only be
  present for test suites.

## 0.2.16

- Deprecate `LiveTestController.liveTest`, the `LiveTestController` instance now
  implements `LiveTest` and can be used directly.

## 0.2.15

- Cancel any StreamQueue that is created as a part of a stream matcher once it
  is done matching.
  - This fixes a bug where using a matcher on a custom stream controller and
    then awaiting the `close()` method on that controller would hang.
- Avoid causing the test runner to hang if there is a timeout during a
  `tearDown` callback following a failing test case.

## 0.2.14

- Bump minimum SDK to `2.4.0` for safer usage of for-loop elements.

## 0.2.13

- Work around a bug in the `2.3.0` SDK by avoiding for-loop elements at the top
  level.

## 0.2.12

- Link to docs on setting timeout when a test times out with the default
  duration.
- No longer directly depend on `package:pedantic`.

## 0.2.11

- Extend the timeout for synthetic tests, e.g. `tearDownAll`.

## 0.2.10

- Update to latest `package:matcher`. Improves output for instances of private
  classes.

## 0.2.9

- Treat non-solo tests as skipped so they are properly reported.

## 0.2.8

- Remove logic which accounted for a race condition in state change. The logic
  was required because `package:sse` used to not guarantee order. This is no
  longer the case.

## 0.2.7

- Prepare for upcoming `Stream<List<int>>` changes in the Dart SDK.
- Mark `package:test_api` as deprecated to prevent accidental use.

## 0.2.6

- Don't swallow exceptions from callbacks in `expectAsync*`.
- Internal cleanup - fix lints.
- Fixed a race condition that caused tests to occasionally fail during
  `tearDownAll` with the message `(tearDownAll) - did not complete [E]`.

## 0.2.5

- Expose the `Metadata`, `PlatformSelector`, `Runtime`, and `SuitePlatform`
  classes publicly through a new `backend.dart` import.

## 0.2.4

- Allow `stream_channel` version `2.0.0`.

## 0.2.3

- Update to matcher version `0.12.5`.

## 0.2.2

- Require Dart SDK `>=2.1.0`.

## 0.2.1

- Add `remote_listener.dart` and `suite_channel_manager.dart`.

## 0.2.0

- Remove "runner" extensions.

## 0.1.1

- Update `stack_trace_formatter` to fold `test_api` frames by default.

## 0.1.0

- Initial release of `test_api`. Provides the basic API for writing tests and
  touch points for implementing a custom test runner.
