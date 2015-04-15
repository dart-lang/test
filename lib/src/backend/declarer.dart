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
  ///
  /// The description will be added to the descriptions of any surrounding
  /// [group]s.
  ///
  /// If [testOn] is passed, it's parsed as a [PlatformSelector], and the test
  /// will only be run on matching platforms.
  ///
  /// If [timeout] is passed, it's used to modify or replace the default timeout
  /// of 30 seconds. Timeout modifications take precedence in suite-group-test
  /// order, so [timeout] will also modify any timeouts set on the group or
  /// suite.
  void test(String description, body(), {String testOn, Timeout timeout}) {
    // TODO(nweiz): Once tests have begun running, throw an error if [test] is
    // called.
    var prefix = _group.description;
    if (prefix != null) description = "$prefix $description";

    var metadata = _group.metadata.merge(
        new Metadata.parse(testOn: testOn, timeout: timeout));
    var group = _group;
    _tests.add(new LocalTest(description, metadata, () {
      // TODO(nweiz): It might be useful to throw an error here if a test starts
      // running while other tests from the same declarer are also running,
      // since they might share closurized state.
      return group.runSetUp().then((_) => body());
    }, tearDown: group.runTearDown));
  }

  /// Creates a group of tests.
  ///
  /// A group's description is included in the descriptions of any tests or
  /// sub-groups it contains. [setUp] and [tearDown] are also scoped to the
  /// containing group.
  ///
  /// If [testOn] is passed, it's parsed as a [PlatformSelector], and any tests
  /// in the group will only be run on matching platforms.
  ///
  /// If [timeout] is passed, it's used to modify or replace the default timeout
  /// of 30 seconds. Timeout modifications take precedence in suite-group-test
  /// order, so [timeout] will also modify any timeouts set on the group or
  /// suite.
  void group(String description, void body(), {String testOn,
      Timeout timeout}) {
    var oldGroup = _group;

    var metadata = new Metadata.parse(testOn: testOn, timeout: timeout);
    _group = new Group(oldGroup, description, metadata);
    try {
      body();
    } finally {
      _group = oldGroup;
    }
  }

  /// Registers a function to be run before tests.
  ///
  /// This function will be called before each test is run. [callback] may be
  /// asynchronous; if so, it must return a [Future].
  ///
  /// If this is called within a [group], it applies only to tests in that
  /// group. [callback] will be run after any set-up callbacks in parent groups
  /// or at the top level.
  void setUp(callback()) {
    if (_group.setUp != null) {
      throw new StateError("setUp() may not be called multiple times for the "
          "same group.");
    }

    _group.setUp = callback;
  }

  /// Registers a function to be run after tests.
  ///
  /// This function will be called after each test is run. [callback] may be
  /// asynchronous; if so, it must return a [Future].
  ///
  /// If this is called within a [group], it applies only to tests in that
  /// group. [callback] will be run before any tear-down callbacks in parent
  /// groups or at the top level.
  void tearDown(callback()) {
    if (_group.tearDown != null) {
      throw new StateError("tearDown() may not be called multiple times for "
          "the same group.");
    }

    _group.tearDown = callback;
  }
}
