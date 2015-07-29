// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.runner_suite;

import 'dart:async';

import 'package:async/async.dart';

import '../backend/metadata.dart';
import '../backend/operating_system.dart';
import '../backend/suite.dart';
import '../backend/test.dart';
import '../backend/test_platform.dart';
import '../utils.dart';

/// A suite produced and consumed by the test runner that has runner-specific
/// logic and lifecycle management.
///
/// This is separated from [Suite] because the backend library (which will
/// eventually become its own package) is primarily for test code itself to use,
/// for which the [RunnerSuite] APIs don't make sense.
class RunnerSuite extends Suite {
  /// The memoizer for running [close] exactly once.
  final _closeMemo = new AsyncMemoizer();

  /// The function to call when the suite is closed.
  final AsyncFunction _onClose;

  RunnerSuite(Iterable<Test> tests, {String path, TestPlatform platform,
          OperatingSystem os, Metadata metadata, AsyncFunction onClose})
      : super(tests,
          path: path, platform: platform, os: os, metadata: metadata),
        _onClose = onClose;

  /// Creates a new [RunnerSuite] with the same properties as [suite].
  RunnerSuite.fromSuite(Suite suite)
      : super(suite.tests,
          path: suite.path,
          platform: suite.platform,
          os: suite.os,
          metadata: suite.metadata),
        _onClose = null;

  RunnerSuite change({String path, Metadata metadata, Iterable<Test> tests}) {
    if (path == null) path = this.path;
    if (metadata == null) metadata = this.metadata;
    if (tests == null) tests = this.tests;
    return new RunnerSuite(tests, platform: platform, os: os, path: path,
        metadata: metadata, onClose: this.close);
  }

  /// Closes the suite and releases any resources associated with it.
  Future close() {
    return _closeMemo.runOnce(() async {
      if (_onClose != null) await _onClose();
    });
  }
}
