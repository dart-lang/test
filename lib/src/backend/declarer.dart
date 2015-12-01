// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.declarer;

import 'dart:async';

import '../frontend/timeout.dart';
import '../utils.dart';
import 'group.dart';
import 'group_entry.dart';
import 'invoker.dart';
import 'metadata.dart';
import 'test.dart';

/// A class that manages the state of tests as they're declared.
///
/// A nested tree of Declarers tracks the current group, set-up, and tear-down
/// functions. Each Declarer in the tree corresponds to a group. This tree is
/// tracked by a zone-scoped "current" Declarer; the current declarer can be set
/// for a block using [Declarer.declare], and it can be accessed using
/// [Declarer.current].
class Declarer {
  /// The parent declarer, or `null` if this corresponds to the root group.
  final Declarer _parent;

  /// The name of the current test group, including the name of any parent
  /// groups.
  ///
  /// This is `null` if this is the root group.
  final String _name;

  /// The metadata for this group, including the metadata of any parent groups
  /// and of the test suite.
  final Metadata _metadata;

  /// The set-up functions to run for each test in this group.
  final _setUps = new List<AsyncFunction>();

  /// The tear-down functions to run for each test in this group.
  final _tearDowns = new List<AsyncFunction>();

  /// The set-up functions to run once for this group.
  final _setUpAlls = new List<AsyncFunction>();

  /// The tear-down functions to run once for this group.
  final _tearDownAlls = new List<AsyncFunction>();

  /// The children of this group, either tests or sub-groups.
  final _entries = new List<GroupEntry>();

  /// Whether [build] has been called for this declarer.
  bool _built = false;

  /// The current zone-scoped declarer.
  static Declarer get current => Zone.current[#test.declarer];

  /// Creates a new declarer for the root group.
  ///
  /// This is the implicit group that exists outside of any calls to `group()`.
  /// If [metadata] is passed, it's used as the metadata for the implicit root
  /// group.
  Declarer([Metadata metadata])
      : this._(null, null, metadata == null ? new Metadata() : metadata);

  Declarer._(this._parent, this._name, this._metadata);

  /// Runs [body] with this declarer as [Declarer.current].
  ///
  /// Returns the return value of [body].
  declare(body()) => runZoned(body, zoneValues: {#test.declarer: this});

  /// Defines a test case with the given name and body.
  void test(String name, body(), {String testOn, Timeout timeout, skip,
      Map<String, dynamic> onPlatform, tags}) {
    _checkNotBuilt("test");

    var metadata = _metadata.merge(new Metadata.parse(
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform,
        tags: tags));

    _entries.add(new LocalTest(_prefix(name), metadata, () {
      // TODO(nweiz): It might be useful to throw an error here if a test starts
      // running while other tests from the same declarer are also running,
      // since they might share closurized state.

      // TODO(nweiz): Use async/await here once issue 23497 has been fixed in
      // two stable versions.
      return Invoker.current.waitForOutstandingCallbacks(() {
        return _runSetUps().then((_) => body());
      }).then((_) => _runTearDowns());
    }));
  }

  /// Creates a group of tests.
  void group(String name, void body(), {String testOn, Timeout timeout, skip,
      Map<String, dynamic> onPlatform, tags}) {
    _checkNotBuilt("group");

    var metadata = _metadata.merge(new Metadata.parse(
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform,
        tags: tags));

    // Don't load the tests for a skipped group.
    if (metadata.skip) {
      _entries.add(new Group(name, [], metadata: metadata));
      return;
    }

    var declarer = new Declarer._(this, _prefix(name), metadata);
    declarer.declare(body);
    _entries.add(declarer.build());
  }

  /// Returns [name] prefixed with this declarer's group name.
  String _prefix(String name) => _name == null ? name : "$_name $name";

  /// Registers a function to be run before each test in this group.
  void setUp(callback()) {
    _checkNotBuilt("setUp");
    _setUps.add(callback);
  }

  /// Registers a function to be run after each test in this group.
  void tearDown(callback()) {
    _checkNotBuilt("tearDown");
    _tearDowns.add(callback);
  }

  /// Registers a function to be run once before all tests.
  void setUpAll(callback()) {
    _checkNotBuilt("setUpAll");
    _setUpAlls.add(callback);
  }

  /// Registers a function to be run once after all tests.
  void tearDownAll(callback()) {
    _checkNotBuilt("tearDownAll");
    _tearDownAlls.add(callback);
  }

  /// Finalizes and returns the group being declared.
  Group build() {
    _checkNotBuilt("build");

    _built = true;
    return new Group(_name, _entries.toList(),
        metadata: _metadata,
        setUpAll: _setUpAll,
        tearDownAll: _tearDownAll);
  }

  /// Throws a [StateError] if [build] has been called.
  ///
  /// [name] should be the name of the method being called.
  void _checkNotBuilt(String name) {
    if (!_built) return;
    throw new StateError("Can't call $name() once tests have begun running.");
  }

  /// Run the set-up functions for this and any parent groups.
  ///
  /// If no set-up functions are declared, this returns a [Future] that
  /// completes immediately.
  Future _runSetUps() {
    // TODO(nweiz): Use async/await here once issue 23497 has been fixed in two
    // stable versions.
    if (_parent != null) {
      return _parent._runSetUps().then((_) {
        return Future.forEach(_setUps, (setUp) => setUp());
      });
    }

    return Future.forEach(_setUps, (setUp) => setUp());
  }

  /// Run the tear-up functions for this and any parent groups.
  ///
  /// If no set-up functions are declared, this returns a [Future] that
  /// completes immediately.
  ///
  /// This should only be called within a test.
  Future _runTearDowns() {
    return Invoker.current.unclosable(() {
      var tearDowns = [];
      for (var declarer = this; declarer != null; declarer = declarer._parent) {
        tearDowns.addAll(declarer._tearDowns.reversed);
      }

      return Future.forEach(tearDowns, _errorsDontStopTest);
    });
  }

  /// Returns a [Test] that runs the callbacks in [_setUpAll].
  Test get _setUpAll {
    if (_setUpAlls.isEmpty) return null;

    return new LocalTest(_prefix("(setUpAll)"), _metadata, () {
      return Future.forEach(_setUpAlls, (setUp) => setUp());
    });
  }

  /// Returns a [Test] that runs the callbacks in [_tearDownAll].
  Test get _tearDownAll {
    if (_tearDownAlls.isEmpty) return null;

    return new LocalTest(_prefix("(tearDownAll)"), _metadata, () {
      return Invoker.current.unclosable(() {
        return Future.forEach(_tearDownAlls.reversed, _errorsDontStopTest);
      });
    });
  }

  /// Runs [body] with special error-handling behavior.
  ///
  /// Errors emitted [body] will still cause the current test to fail, but they
  /// won't cause it to *stop*. In particular, they won't remove any outstanding
  /// callbacks registered outside of [body].
  Future _errorsDontStopTest(body()) {
    var completer = new Completer();

    Invoker.current.addOutstandingCallback();
    Invoker.current.waitForOutstandingCallbacks(() {
      new Future.sync(body).whenComplete(completer.complete);
    }).then((_) => Invoker.current.removeOutstandingCallback());

    return completer.future;
  }
}
