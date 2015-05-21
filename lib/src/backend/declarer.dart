// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.declarer;

import 'dart:collection';

import '../frontend/timeout.dart';
import 'group.dart';
import 'invoker.dart';
import 'metadata.dart';
import 'test.dart';

/// A class that manages the state of tests as they're declared.
///
/// This is in charge of tracking the current group, set-up, and tear-down
/// functions. It produces a list of runnable [tests].
class Declarer {
  /// The current group.
  var _group = new Group.root();

  /// The list of tests that have been defined.
  List<Test> get tests => new UnmodifiableListView<Test>(_tests);
  final _tests = new List<Test>();

  Declarer();

  /// Defines a test case with the given description and body.
  void test(String description, body(), {String testOn, Timeout timeout,
      skip, Map<String, dynamic> onPlatform}) {
    // TODO(nweiz): Once tests have begun running, throw an error if [test] is
    // called.
    var prefix = _group.description;
    if (prefix != null) description = "$prefix $description";

    var metadata = _group.metadata.merge(new Metadata.parse(
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform));

    var group = _group;
    _tests.add(new LocalTest(description, metadata, () {
      // TODO(nweiz): It might be useful to throw an error here if a test starts
      // running while other tests from the same declarer are also running,
      // since they might share closurized state.

      // TODO(nweiz): Use async/await here once issue 23497 has been fixed in
      // two stable versions.
      return group.runSetUp().then((_) => body());
    }, tearDown: group.runTearDown));
  }

  /// Creates a group of tests.
  void group(String description, void body(), {String testOn,
      Timeout timeout, skip, Map<String, dynamic> onPlatform}) {
    var oldGroup = _group;

    var metadata = new Metadata.parse(
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform);

    // Don' load the tests for a skipped group.
    if (metadata.skip) {
      _tests.add(new LocalTest(description, metadata, () {}));
      return;
    }

    _group = new Group(oldGroup, description, metadata);
    try {
      body();
    } finally {
      _group = oldGroup;
    }
  }

  /// Registers a function to be run before tests.
  void setUp(callback()) {
    if (_group.setUp != null) {
      throw new StateError("setUp() may not be called multiple times for the "
          "same group.");
    }

    _group.setUp = callback;
  }

  /// Registers a function to be run after tests.
  void tearDown(callback()) {
    if (_group.tearDown != null) {
      throw new StateError("tearDown() may not be called multiple times for "
          "the same group.");
    }

    _group.tearDown = callback;
  }
}
