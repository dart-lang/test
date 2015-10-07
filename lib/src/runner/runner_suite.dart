// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.runner_suite;

import 'dart:async';

import 'package:async/async.dart';

import '../backend/operating_system.dart';
import '../backend/suite.dart';
import '../backend/group.dart';
import '../backend/test.dart';
import '../backend/test_platform.dart';
import '../utils.dart';
import 'environment.dart';

/// A suite produced and consumed by the test runner that has runner-specific
/// logic and lifecycle management.
///
/// This is separated from [Suite] because the backend library (which will
/// eventually become its own package) is primarily for test code itself to use,
/// for which the [RunnerSuite] APIs don't make sense.
class RunnerSuite extends Suite {
  final Environment environment;

  /// The memoizer for running [close] exactly once.
  final _closeMemo = new AsyncMemoizer();

  /// The function to call when the suite is closed.
  final AsyncFunction _onClose;

  RunnerSuite(this.environment, Group group, {String path,
          TestPlatform platform, OperatingSystem os, AsyncFunction onClose})
      : super(group, path: path, platform: platform, os: os),
        _onClose = onClose;

  RunnerSuite filter(bool callback(Test test)) {
    var filtered = group.filter(callback);
    filtered ??= new Group.root([], metadata: metadata);
    return new RunnerSuite(environment, filtered,
      platform: platform, os: os, path: path);
  }

  /// Closes the suite and releases any resources associated with it.
  Future close() {
    return _closeMemo.runOnce(() async {
      if (_onClose != null) await _onClose();
    });
  }
}
