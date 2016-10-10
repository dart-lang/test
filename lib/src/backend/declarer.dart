// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

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

  /// The stack trace for this group.
  final Trace _trace;

  /// Whether to collect stack traces for [GroupEntry]s.
  final bool _collectTraces;

  /// The set-up functions to run for each test in this group.
  final _setUps = new List<AsyncFunction>();

  /// The tear-down functions to run for each test in this group.
  final _tearDowns = new List<AsyncFunction>();

  /// The set-up functions to run once for this group.
  final _setUpAlls = new List<AsyncFunction>();

  /// The trace for the first call to [setUpAll].
  ///
  /// All [setUpAll]s are run in a single logical test, so they can only have
  /// one trace. The first trace is most often correct, since the first
  /// [setUpAll] is always run and the rest are only run if that one succeeds.
  Trace _setUpAllTrace;

  /// The tear-down functions to run once for this group.
  final _tearDownAlls = new List<AsyncFunction>();

  /// The trace for the first call to [tearDownAll].
  ///
  /// All [tearDownAll]s are run in a single logical test, so they can only have
  /// one trace. The first trace matches [_setUpAllTrace].
  Trace _tearDownAllTrace;

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
  ///
  /// If [collectTraces] is `true`, this will set [GroupEntry.trace] for all
  /// entries built by the declarer. Note that this can be noticeably slow when
  /// thousands of tests are being declared (see #457).
  Declarer({Metadata metadata, bool collectTraces: false})
      : this._(null, null, metadata ?? new Metadata(), collectTraces, null);

  Declarer._(this._parent, this._name, this._metadata, this._collectTraces,
      this._trace);

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

    _entries.add(new LocalTest(_prefix(name), metadata, () async {
      // TODO(nweiz): It might be useful to throw an error here if a test starts
      // running while other tests from the same declarer are also running,
      // since they might share closurized state.

      await Invoker.current.waitForOutstandingCallbacks(() async {
        await _runSetUps();
        await body();
      });
      await _runTearDowns();
    }, trace: _collectTraces ? new Trace.current(2) : null));
  }

  /// Creates a group of tests.
  void group(String name, void body(), {String testOn, Timeout timeout, skip,
      Map<String, dynamic> onPlatform, tags}) {
    _checkNotBuilt("group");

    var metadata = _metadata.merge(new Metadata.parse(
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform,
        tags: tags));
    var trace = _collectTraces ? new Trace.current(2) : null;

    var declarer = new Declarer._(
        this, _prefix(name), metadata, _collectTraces, trace);
    declarer.declare(() {
      // Cast to dynamic to avoid the analyzer complaining about us using the
      // result of a void method.
      var result = (body as dynamic)();
      if (result is! Future) return;
      throw new ArgumentError("Groups may not be async.");
    });
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
    if (_collectTraces) _setUpAllTrace ??= new Trace.current(2);
    _setUpAlls.add(callback);
  }

  /// Registers a function to be run once after all tests.
  void tearDownAll(callback()) {
    _checkNotBuilt("tearDownAll");
    if (_collectTraces) _tearDownAllTrace ??= new Trace.current(2);
    _tearDownAlls.add(callback);
  }

  /// Finalizes and returns the group being declared.
  Group build() {
    _checkNotBuilt("build");

    _built = true;
    return new Group(_name, _entries.toList(),
        metadata: _metadata,
        trace: _trace,
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
  Future _runSetUps() async {
    if (_parent != null) await _parent._runSetUps();
    await Future.forEach(_setUps, (setUp) => setUp());
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
    }, trace: _setUpAllTrace);
  }

  /// Returns a [Test] that runs the callbacks in [_tearDownAll].
  Test get _tearDownAll {
    if (_tearDownAlls.isEmpty) return null;

    return new LocalTest(_prefix("(tearDownAll)"), _metadata, () {
      return Invoker.current.unclosable(() {
        return Future.forEach(_tearDownAlls.reversed, _errorsDontStopTest);
      });
    }, trace: _tearDownAllTrace);
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
