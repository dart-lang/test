## 0.2.9

* Treat non-solo tests as skipped so they are properly reported.

## 0.2.8

* Remove logic which accounted for a race condition in state change. The logic
  was required because `package:sse` used to not guarantee order. This is no
  longer the case.

## 0.2.7

* Prepare for upcoming `Stream<List<int>>` changes in the Dart SDK.
* Mark `package:test_api` as deprecated to prevent accidental use.

## 0.2.6

* Don't swallow exceptions from callbacks in `expectAsync*`.
* Internal cleanup - fix lints.
* Fixed a race condition that caused tests to occasionally fail during
  `tearDownAll` with the message `(tearDownAll) - did not complete [E]`.

## 0.2.5

* Expose the  `Metadata`, `PlatformSelector`, `Runtime`, and `SuitePlatform`
  classes publicly through a new `backend.dart` import.

## 0.2.4

* Allow `stream_channel` version `2.0.0`.

## 0.2.3

* Update to matcher version `0.12.5`.

## 0.2.2

* Require Dart SDK `>=2.1.0`.

## 0.2.1

* Add `remote_listener.dart` and `suite_channel_manager.dart`.

## 0.2.0

* Remove "runner" extensions.


## 0.1.1

* Update `stack_trace_formatter` to fold `test_api` frames by default.


## 0.1.0

* Initial release of `test_api`. Provides the basic API for writing tests and
  touch points for implementing a custom test runner.
