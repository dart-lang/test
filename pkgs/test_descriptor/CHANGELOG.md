## 1.2.1

* Fix outdated URLs in `README.md`.

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
