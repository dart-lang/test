// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Access to runtime information and shared resources for the current test
/// environment.
abstract final class TestEnvironment {
  /// The file system path to the temporary session directory created for the
  /// current test run.
  ///
  /// Throws an [UnsupportedError] if called on a platform where `dart:io` is unavailable.
  static String get sessionDirectory => throw UnsupportedError(
    'Accessing TestEnvironment.sessionDirectory is only supported where dart:io exists',
  );
}
