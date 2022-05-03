## 2.0.1-dev

* Populate the pubspec `repository` field.
* Migrate to `package:lints`.

## 2.0.0

* Null safety stable release.
* BREAKING: Removed archive support.
* BREAKING: `DirectoryDescriptor.load` only supports a `String` path instead of
  also accepting relative `Uri` objects.
* BREAKING: `DirectoryDescriptor.load` no longer has an optional `parents`
  parameter - this was intended for internal use only.

## 1.2.0

* Add an `ArchiveDescriptor` class and a corresponding `archive()` function that
  can create and validate Zip and TAR archives.

## 1.1.1

* Update to lowercase Dart core library constants.

## 1.1.0

* Add a `path()` function that returns the a path within the sandbox directory.

* Add `io` getters to `FileDescriptor` and `DirectoryDescriptor` that returns
  `dart:io` `File` and `Directory` objects, respectively, within the sandbox
  directory.

## 1.0.4

* Support test `1.x.x'.

## 1.0.3

* Stop using comment-based generics.

## 1.0.2

* Declare support for `async` 2.0.0.

## 1.0.1

* `FileDescriptor.validate()` now allows invalid UTF-8 files.

* Fix a bug where `DirectoryDescriptor.load()` would incorrectly report that
  multiple versions of a file or directory existed.

## 1.0.0

* Initial version.
