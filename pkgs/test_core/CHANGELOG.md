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
