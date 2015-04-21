// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.suite;

import 'dart:collection';

import 'metadata.dart';
import 'operating_system.dart';
import 'test.dart';
import 'test_platform.dart';

/// A test suite.
///
/// A test suite is a set of tests that are intended to be run together and that
/// share default configuration.
class Suite {
  /// A description of the platform on which the suite is running, or `null` if
  /// that platform is unknown.
  final String platform;

  /// The path to the Dart test suite, or `null` if that path is unknown.
  final String path;

  /// The metadata associated with this test suite.
  final Metadata metadata;

  /// The tests in the test suite.
  final List<Test> tests;

  Suite(Iterable<Test> tests, {this.path, this.platform, Metadata metadata})
      : metadata = metadata == null ? new Metadata() : metadata,
        tests = new UnmodifiableListView<Test>(tests.toList());

  /// Returns a view of this suite for the given [platform] and [os].
  ///
  /// This filters out tests that are invalid for [platform] and [os] and
  /// resolves platform-specific metadata. If the suite itself is invalid for
  /// [platform] and [os], returns `null`.
  Suite forPlatform(TestPlatform platform, {OperatingSystem os}) {
    if (!metadata.testOn.evaluate(platform, os: os)) return null;
    return change(tests: tests.where((test) {
      return test.metadata.testOn.evaluate(platform, os: os);
    }).map((test) {
      return test.change(metadata: test.metadata.forPlatform(platform, os: os));
    }));
  }

  /// Returns a new suite with the given fields updated.
  Suite change({String path, String platform, Metadata metadata,
      Iterable<Test> tests}) {
    if (path == null) path = this.path;
    if (platform == null) platform = this.platform;
    if (metadata == null) metadata = this.metadata;
    if (tests == null) tests = this.tests;
    return new Suite(tests, path: path, platform: platform, metadata: metadata);
  }
}
