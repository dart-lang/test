// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stack_trace/stack_trace.dart';

import 'group.dart';
import 'metadata.dart';
import 'suite_platform.dart';
import 'test.dart';
import 'test_location.dart';

/// A [Test] or [Group].
abstract class GroupEntry {
  /// The name of the entry, including the prefixes from any containing
  /// [Group]s.
  ///
  /// This will be empty for the root group.
  String get name;

  /// The parent of this entry.
  ///
  /// This field is set during during building in the Declarer and also during
  /// deserialization of the parent.
  Group? parent;

  /// The metadata for the entry, including the metadata from any containing
  /// [Group]s.
  Metadata get metadata;

  /// The stack trace for the call to `test()` or `group()` that defined this
  /// entry, or `null` if the entry was defined in a different way.
  Trace? get trace;

  /// An optional location provided to `test()` or `group()` to support test
  /// frameworks like pkg:test_reflective_loader where the test/group location
  /// might not be in [trace] at the time `test()` or `group()` are called.
  ///
  /// If `null`, the location of a test will try to be inferred from [trace].
  TestLocation? get location;

  /// Returns a copy of [this] with all platform-specific metadata resolved.
  ///
  /// Removes any tests and groups with [Metadata.testOn] selectors that don't
  /// match [platform]. Returns `null` if this entry's selector doesn't match.
  GroupEntry? forPlatform(SuitePlatform platform);

  /// Returns a copy of [this] with all tests that don't match [callback]
  /// removed.
  ///
  /// Returns `null` if this is a test that doesn't match [callback] or a group
  /// where no child tests match [callback].
  GroupEntry? filter(bool Function(Test) callback);

  /// Returns a clone of this object without the internal `parent` reference
  /// set so that it may be attached to a new tree.
  GroupEntry? clone();
}
