// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:stack_trace/stack_trace.dart';

import '../frontend/timeout.dart';
import '../util/test.dart';
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

  /// The set of variables that are valid for platform selectors, in addition to
  /// the built-in variables that are allowed everywhere.
  final Set<String> _platformVariables;

  /// The stack trace for this group.
  final Trace _trace;

  /// Whether to collect stack traces for [GroupEntry]s.
  final bool _collectTraces;

  /// Whether to disable retries of tests.
  final bool _noRetry;

  /// The set-up functions to run for each test in this group.
  final _setUps = List<Function()>();

  /// The tear-down functions to run for each test in this group.
  final _tearDowns = List<Function()>();

  /// The set-up functions to run once for this group.
  final _setUpAlls = List<Function()>();

  /// The trace for the first call to [setUpAll].
  ///
  /// All [setUpAll]s are run in a single logical test, so they can only have
  /// one trace. The first trace is most often correct, since the first
  /// [setUpAll] is always run and the rest are only run if that one succeeds.
  Trace _setUpAllTrace;

  /// The tear-down functions to run once for this group.
  final _tearDownAlls = List<Function()>();

  /// The trace for the first call to [tearDownAll].
  ///
  /// All [tearDownAll]s are run in a single logical test, so they can only have
  /// one trace. The first trace matches [_setUpAllTrace].
  Trace _tearDownAllTrace;

  /// The children of this group, either tests or sub-groups.
  final _entries = List<GroupEntry>();

  /// Whether [build] has been called for this declarer.
  bool _built = false;

  /// The tests and/or groups that have been flagged as solo.
  final _soloEntries = Set<GroupEntry>();

  /// Whether any tests and/or groups have been flagged as solo.
  bool get _solo => _soloEntries.isNotEmpty;

  /// The current zone-scoped declarer.
  static Declarer get current => Zone.current[#test.declarer] as Declarer;

  /// Creates a new declarer for the root group.
  ///
  /// This is the implicit group that exists outside of any calls to `group()`.
  /// If [metadata] is passed, it's used as the metadata for the implicit root
  /// group.
  ///
  /// The [platformVariables] are the set of variables that are valid for
  /// platform selectors in test and group metadata, in addition to the built-in
  /// variables that are allowed everywhere.
  ///
  /// If [collectTraces] is `true`, this will set [GroupEntry.trace] for all
  /// entries built by the declarer. Note that this can be noticeably slow when
  /// thousands of tests are being declared (see #457).
  ///
  /// If [noRetry] is `true` tests will be run at most once.
  Declarer(
      {Metadata metadata,
      Set<String> platformVariables,
      bool collectTraces = false,
      bool noRetry = false})
      : this._(
            null,
            null,
            metadata ?? Metadata(),
            platformVariables ?? const UnmodifiableSetView.empty(),
            collectTraces,
            null,
            noRetry);

  Declarer._(this._parent, this._name, this._metadata, this._platformVariables,
      this._collectTraces, this._trace, this._noRetry);

  /// Runs [body] with this declarer as [Declarer.current].
  ///
  /// Returns the return value of [body].
  declare(body()) => runZoned(body, zoneValues: {#test.declarer: this});

  /// Defines a test case with the given name and body.
  void test(String name, body(),
      {String testOn,
      Timeout timeout,
      skip,
      Map<String, dynamic> onPlatform,
      tags,
      int retry,
      bool solo = false}) {
    _checkNotBuilt("test");

    var newMetadata = Metadata.parse(
        testOn: testOn,
        timeout: timeout,
        skip: skip,
        onPlatform: onPlatform,
        tags: tags,
        retry: _noRetry ? 0 : retry);
    newMetadata.validatePlatformSelectors(_platformVariables);
    var metadata = _metadata.merge(newMetadata);

    _entries.add(LocalTest(_prefix(name), metadata, () async {
      var parents = <Declarer>[];
      for (var declarer = this; declarer != null; declarer = declarer._parent) {
        parents.add(declarer);
      }

      // Register all tear-down functions in all declarers. Iterate through
      // parents outside-in so that the Invoker gets the functions in the order
      // they were declared in source.
      for (var declarer in parents.reversed) {
        for (var tearDown in declarer._tearDowns) {
          Invoker.current.addTearDown(tearDown);
        }
      }

      await runZoned(
          () => Invoker.current.waitForOutstandingCallbacks(() async {
                await _runSetUps();
                await body();
              }),
          // Make the declarer visible to running tests so that they'll throw
          // useful errors when calling `test()` and `group()` within a test.
          zoneValues: {#test.declarer: this});
    }, trace: _collectTraces ? Trace.current(2) : null, guarded: false));

    if (solo) {
      _soloEntries.add(_entries.last);
    }
  }

  /// Creates a group of tests.
  void group(String name, void body(),
      {String testOn,
      Timeout timeout,
      skip,
      Map<String, dynamic> onPlatform,
      tags,
      int retry,
      bool solo = false}) {
    _checkNotBuilt("group");

    var newMetadata = Metadata.parse(
        testOn: testOn,
        timeout: timeout,
        skip: skip,
        onPlatform: onPlatform,
        tags: tags,
        retry: _noRetry ? 0 : retry);
    newMetadata.validatePlatformSelectors(_platformVariables);
    var metadata = _metadata.merge(newMetadata);
    var trace = _collectTraces ? Trace.current(2) : null;

    var declarer = Declarer._(this, _prefix(name), metadata, _platformVariables,
        _collectTraces, trace, _noRetry);
    declarer.declare(() {
      // Cast to dynamic to avoid the analyzer complaining about us using the
      // result of a void method.
      var result = (body as dynamic)();
      if (result is! Future) return;
      throw ArgumentError("Groups may not be async.");
    });
    _entries.add(declarer.build());

    if (solo || declarer._solo) {
      _soloEntries.add(_entries.last);
    }
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
    if (_collectTraces) _setUpAllTrace ??= Trace.current(2);
    _setUpAlls.add(callback);
  }

  /// Registers a function to be run once after all tests.
  void tearDownAll(callback()) {
    _checkNotBuilt("tearDownAll");
    if (_collectTraces) _tearDownAllTrace ??= Trace.current(2);
    _tearDownAlls.add(callback);
  }

  /// Like [tearDownAll], but called from within a running [setUpAll] test to
  /// dynamically add a [tearDownAll].
  void addTearDownAll(callback()) => _tearDownAlls.add(callback);

  /// Finalizes and returns the group being declared.
  ///
  /// **Note**: The tests in this group must be run in a [Invoker.guard]
  /// context; otherwise, test errors won't be captured.
  Group build() {
    _checkNotBuilt("build");

    _built = true;
    var entries = _entries.toList();
    if (_solo) entries.removeWhere((entry) => !_soloEntries.contains(entry));

    return Group(_name, entries,
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
    throw StateError("Can't call $name() once tests have begun running.");
  }

  /// Run the set-up functions for this and any parent groups.
  ///
  /// If no set-up functions are declared, this returns a [Future] that
  /// completes immediately.
  Future _runSetUps() async {
    if (_parent != null) await _parent._runSetUps();
    await Future.forEach(_setUps, (setUp) => setUp());
  }

  /// Returns a [Test] that runs the callbacks in [_setUpAll].
  Test get _setUpAll {
    if (_setUpAlls.isEmpty) return null;

    return LocalTest(_prefix("(setUpAll)"), _metadata, () {
      return runZoned(() => Future.forEach(_setUpAlls, (setUp) => setUp()),
          // Make the declarer visible to running scaffolds so they can add to
          // the declarer's `tearDownAll()` list.
          zoneValues: {#test.declarer: this});
    }, trace: _setUpAllTrace, guarded: false, isScaffoldAll: true);
  }

  /// Returns a [Test] that runs the callbacks in [_tearDownAll].
  Test get _tearDownAll {
    // We have to create a tearDownAll if there's a setUpAll, since it might
    // dynamically add tear-down code using [addTearDownAll].
    if (_setUpAlls.isEmpty && _tearDownAlls.isEmpty) return null;

    return LocalTest(_prefix("(tearDownAll)"), _metadata, () {
      return runZoned(() {
        return Invoker.current.unclosable(() async {
          while (_tearDownAlls.isNotEmpty) {
            await errorsDontStopTest(_tearDownAlls.removeLast());
          }
        });
      },
          // Make the declarer visible to running scaffolds so they can add to
          // the declarer's `tearDownAll()` list.
          zoneValues: {#test.declarer: this});
    }, trace: _tearDownAllTrace, guarded: false, isScaffoldAll: true);
  }
}
