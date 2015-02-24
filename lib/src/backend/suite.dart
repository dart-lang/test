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
  /// The name of the test suite.
  final String name;

  /// The tests in the test suite.
  final List<Test> tests;

  Suite(this.name, Iterable<Test> tests)
      : tests = new UnmodifiableListView<Test>(tests.toList());
}
