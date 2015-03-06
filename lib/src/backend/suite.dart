// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.backend.suite;

import 'dart:collection';

import 'test.dart';

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

  /// The tests in the test suite.
  final List<Test> tests;

  Suite(Iterable<Test> tests, {String path, String platform})
      : path = path,
        platform = platform,
        tests = new UnmodifiableListView<Test>(tests.toList());
}
