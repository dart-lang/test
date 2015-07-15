// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.suite;

import 'dart:async';
import 'dart:collection';

import '../util/async_thunk.dart';
import '../utils.dart';
import 'metadata.dart';
import 'operating_system.dart';
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

  /// The thunk for running [close] exactly once.
  final _closeThunk = new AsyncThunk();

  /// The function to call when the suite is closed.
  final AsyncFunction _onClose;

  /// The tests in the test suite.
  final List<Test> tests;

  /// Creates a new suite containing [tests].
  ///
  /// If [platform] and/or [os] are passed, [tests] and [metadata] are filtered
  /// to match that platform information.
  ///
  /// If [os] is passed without [platform], throws an [ArgumentError].
  Suite(Iterable<Test> tests, {this.path, TestPlatform platform,
          OperatingSystem os, Metadata metadata, AsyncFunction onClose})
      : platform = platform,
        os = os,
        metadata = _filterMetadata(metadata, platform, os),
        _onClose = onClose,
        tests = new UnmodifiableListView<Test>(
            _filterTests(tests, platform, os));

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

  /// Returns [tests] filtered according to [platform] and [os].
  ///
  /// Gracefully handles [platform] being null.
  static List<Test> _filterTests(Iterable<Test> tests,
      TestPlatform platform, OperatingSystem os) {
    if (platform == null) return tests.toList();

    return tests.where((test) {
      return test.metadata.testOn.evaluate(platform, os: os);
    }).map((test) {
      return test.change(metadata: test.metadata.forPlatform(platform, os: os));
    }).toList();
  }

  /// Returns a new suite with the given fields updated.
  ///
  /// In the new suite, [metadata] and [tests] will be filtered according to
  /// [platform] and [os].
  Suite change({String path, Metadata metadata, Iterable<Test> tests}) {
    if (path == null) path = this.path;
    if (metadata == null) metadata = this.metadata;
    if (tests == null) tests = this.tests;
    return new Suite(tests, path: path, metadata: metadata,
        onClose: this.close);
  }

  /// Closes the suite and releases any resources associated with it.
  Future close() {
    return _closeThunk.run(() async {
      if (_onClose != null) await _onClose();
    });
  }
}
