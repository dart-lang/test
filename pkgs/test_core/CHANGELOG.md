## 0.3.12-nullsafety.2-dev

* Allow version `0.40.x` of `analyzer`.

## 0.3.12-nullsafety.1

* Update source_maps constraint.

## 0.3.12-nullsafety

* Migrate to null safety.

## 0.3.11

* Update to `matcher` version `0.12.9`.

## 0.3.10

* Prepare for `unawaited` from `package:meta`.

## 0.3.9

* Ignore a null `RunnerSuite` rather than throw an error.

## 0.3.8

* Update vm bootstrapping logic to ensure the bootstrap library has the same
  language version as the test.
* Populate `languageVersionComment` in the `Metadata` returned from
  `parseMetadata`.

## 0.3.7

* Support the latest `package:coverage`.

## 0.3.6

* Expose the `Configuration` class and related classes through `backend.dart`.

## 0.3.5

* Add additional information to an exception when we end up with a null
  `RunnerSuite`.

* Update vm bootstrapping logic to ensure the bootstrap library has the same
  language version as the test.
* Populate `languageVersionComment` in the `Metadata` returned from
  `parseMetadata`.

## 0.3.4

* Fix error messages for incorrect string literals in test annotations.

## 0.3.3

* Support latest `package:vm_service`.

## 0.3.2

* Drop the `package_resolver` dependency.

## 0.3.1

* Support latest `package:vm_service`.
* Enable asserts in code running through `spawnHybrid` APIs.
* Exit with a non-zero code if no tests were ran, whether due to skips or having
  no tests defined.

## 0.3.0

* Bump minimum SDK to `2.4.0` for safer usage of for-loop elements.
* Deprecate `PhantomJS` and provide warning when used. Support for `PhantomJS`
  will be removed in version `2.0.0`.
* Differentiate between test-randomize-ordering-seed not set and 0 being chosen
  as the random seed.
* `deserializeSuite` now takes an optional `gatherCoverage` callback.
* Support retrying of entire test suites when they fail to load.
* Fix the `compiling` message in precompiled mode so it says `loading` instead,
  which is more accurate.
* Change the behavior of the concurrency setting so that loading and running
  don't have separate pools.
  * The loading and running of a test are now done with the same resource, and
    the concurrency setting uniformly affects each. With `-j1` only a single
    test will ever be loaded at a time.
  * Previously the loading pool was 2x larger than the actual concurrency
    setting which could cause flaky tests due to tests being loaded while
    other tests were running, even with `-j1`.
* Avoid printing uncaught errors within `spawnHybridUri`.

## 0.2.18

* Allow `test_api` `0.2.13` to work around a bug in the SDK version `2.3.0`.

## 0.2.17

* Add `file_reporters` configuration option and `--file-reporter` CLI option to
  allow specifying a separate reporter that writes to a file instead of stdout.

## 0.2.16

* Internal cleanup.
* Add `customHtmlTemplateFile` configuration option to allow sharing an
  html template between tests
* Depend on the latest `test_api`.

## 0.2.15

* Add a `StringSink` argument to reporters to prepare for reporting to a file.
* Add --test-randomize-ordering-seed` argument to randomize test
execution order based on a provided seed
* Depend on the latest `test_api`.

## 0.2.14

* Support the latest `package:analyzer`.
* Update to latest `package:matcher`. Improves output for instances of private
  classes.

## 0.2.13

* Depend on the latest `package:test_api`.

## 0.2.12

* Conditionally import coverage logic in `engine.dart`. This ensures the engine
  is platform agnostic.

## 0.2.11

* Implement code coverage gathering for VM tests.

## 0.2.10

* Add a `--debug` argument for running the VM/Chrome in debug mode.

## 0.2.9+2

* Depend on the latest `test_api`.

## 0.2.9+1

* Allow the latest `package:vm_service`.

## 0.2.9

* Mark `package:test_core` as deprecated to prevent accidental use.
* Depend on the latest `test_api`.

## 0.2.8

* Depend on `vm_service` instead of `vm_service_lib`.
* Drop dependency on `pub_semver`.
* Allow `analyzer` version `0.38.x`.

## 0.2.7

* Depend on `vm_service_lib` instead of `vm_service_client`.
* Depend on latest `package:analyzer`.

## 0.2.6

* Internal cleanup - fix lints.
* Use the latest `test_api`.

## 0.2.5

* Fix an issue where non-completed tests were considered passing.
* Updated `compact` and `expanded` reporters to display non-completed tests.

## 0.2.4

* Avoid `dart:isolate` imports on code loaded in tests.
* Expose the `parseMetadata` function publicly through a new `backend.dart`
  import, as well as re-exporting `package:test_api/backend.dart`.

## 0.2.3

* Switch import for `IsolateChannel` for forwards compatibility with `2.0.0`.

## 0.2.2

* Allow `analyzer` version `0.36.x`.
* Update to matcher version `0.12.5`.

## 0.2.1+1

* Allow `analyzer` version `0.35.x`.

## 0.2.1

* Require Dart SDK `>=2.1.0`.
* Require latest `test_api`.

## 0.2.0

* Remove `remote_listener.dart` and `suite_channel_manager.dart` from runner
  and depend on them from `test_api`.

## 0.1.0

* Initial release of `test_core`. Provides the basic API for writing and running
  tests on the VM.
