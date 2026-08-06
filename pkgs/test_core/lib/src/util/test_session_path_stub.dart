// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The file system path to the temporary session directory created for the current test run.
///
/// Throws an [UnsupportedError] if called on a platform where `dart:io` is unavailable.
String get testSessionPath => throw UnsupportedError(
  'Accessing testSessionPath is only supported where dart:io exists',
);
