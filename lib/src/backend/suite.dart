// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.suite;

import 'dart:collection';

import 'metadata.dart';
import 'operating_system.dart';
import 'suite_entry.dart';
import 'test.dart';
import 'test_platform.dart';

/// A test suite.
///
/// A test suite is a set of tests that are intended to be run together and that
/// share default configuration.
class Suite {
  /// The platform on which the suite is running, or `null` if that platform is
  /// unknown.
  final TestPlatform platform;

  /// The operating system on which the suite is running, or `null` if that
  /// operating system is unknown.
  ///
  /// This will always be `null` if [platform] is `null`.
  final OperatingSystem os;

  /// The path to the Dart test suite, or `null` if that path is unknown.
  final String path;

  /// The metadata associated with this test suite.
  final Metadata metadata;

  /// The tests and groups in this test suite.
  final List<SuiteEntry> entries;

  /// Creates a new suite containing [entires].
  ///
  /// If [platform] and/or [os] are passed, [entries] and [metadata] are filtered
  /// to match that platform information.
  ///
  /// If [os] is passed without [platform], throws an [ArgumentError].
  Suite(Iterable<SuiteEntry> entries, {this.path, TestPlatform platform,
          OperatingSystem os, Metadata metadata})
      : platform = platform,
        os = os,
        metadata = _filterMetadata(metadata, platform, os),
        entries = new UnmodifiableListView<SuiteEntry>(
            _filterEntries(entries, platform, os));

  /// Returns [metadata] filtered according to [platform] and [os].
  ///
  /// Gracefully handles either [metadata] or [platform] being null.
  static Metadata _filterMetadata(Metadata metadata, TestPlatform platform,
      OperatingSystem os) {
    if (platform == null && os != null) {
      throw new ArgumentError.value(null, "os",
          "If os is passed, platform must be passed as well");
    }

    if (metadata == null) return new Metadata();
    if (platform == null) return metadata;
    return metadata.forPlatform(platform, os: os);
  }

  /// Returns [entries] filtered according to [platform] and [os].
  ///
  /// Gracefully handles [platform] being null.
  static List<SuiteEntry> _filterEntries(Iterable<SuiteEntry> entries,
      TestPlatform platform, OperatingSystem os) {
    if (platform == null) return entries.toList();

    return entries.map((entry) {
      return entry.forPlatform(platform, os: os);
    }).where((entry) => entry != null).toList();
  }

  /// Returns a new suite with all tests matching [test] removed.
  ///
  /// Unlike [SuiteEntry.filter], this never returns `null`. If all entries are
  /// filtered out, it returns an empty suite.
  Suite filter(bool callback(Test test)) {
    var filtered = entries
        .map((entry) => entry.filter(callback))
        .where((entry) => entry != null)
        .toList();
    return new Suite(filtered,
      platform: platform, os: os, path: path, metadata: metadata);
  }
}
