## 2.1.1

* Require Dart 3.1.
* Move to `dart-lang/test` monorepo.

## 2.1.0

- Remove the expectation that the process exits during the normal test body.
  The process will still be killed during teardown if it has not exited. The
  check can be manually restored with `shouldExit()`.

## 2.0.3

- Populate the pubspec `repository` field.
- Fixed examples in `readme.md`.
- Added `example/example.dart`
- Require Dart >=2.17

## 2.0.2

- Reverted `meta` constraint to `^1.3.0`.

## 2.0.1

- Update `meta` constraint to `>=1.3.0 <3.0.0`.

## 2.0.0

- Migrate to null safety.

## 1.0.6

- Require Dart >=2.1

## 1.0.5

- Don't allow the test to time out as long as the process is emitting output.

## 1.0.4

- Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 1.0.3

- Support test `1.x.x`.

## 1.0.2

- Update SDK version to 2.0.0-dev.17.0

## 1.0.1

- Declare support for `async` 2.0.0.

## 1.0.0

- Added `pid` and `exitCode` getters to `TestProcess`.

## 1.0.0-rc.2

- Subclassed `TestProcess`es now emit log output based on the superclass's
  standard IO streams rather than the subclass's. This matches the documented
  behavior.

## 1.0.0-rc.1

- Initial release candidate.
