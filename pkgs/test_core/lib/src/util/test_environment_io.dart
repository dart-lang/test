// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Access to runtime information and shared resources for the current test
/// environment.
abstract final class TestEnvironment {
  /// The file system path to the temporary session directory created for the
  /// current test run.
  ///
  /// This directory is shared between `pre_run` hooks, tests in the session,
  /// and `post_run` hooks. It is automatically deleted when the test runner
  /// closes.
  static String get sessionDirectory {
    final envDir = Platform.environment['DART_TEST_SESSION_DIR'];
    if (envDir != null) return envDir;
    return p.absolute(p.join('.dart_tool', 'test', 'sessions', '$pid'));
  }
}
