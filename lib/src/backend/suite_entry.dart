// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.test_or_group;

import 'metadata.dart';
import 'operating_system.dart';
import 'test.dart';
import 'test_platform.dart';

/// A [Test] or [Group].
abstract class SuiteEntry {
  /// The name of the entry, includes the prefixes from any containing [Group]s.
  String get name;

  /// The metadata for the entry, including the metadata from any containing
  /// [Group]s and the test suite.
  Metadata get metadata;

  /// Returns a copy of [this] with all platform-specific metadata resolved.
  ///
  /// Removes any tests and groups with [Metadata.testOn] selectors that don't
  /// match [platform] and [selector]. Returns `null` if this entry's selector
  /// doesn't match.
  SuiteEntry forPlatform(TestPlatform platform, {OperatingSystem os});

  /// Returns a copy of [this] with all tests that don't match [callback]
  /// removed.
  ///
  /// Returns `null` if this is a test that doesn't match [callback] or a group
  /// where no child tests match [callback].
  SuiteEntry filter(bool callback(Test test));
}
