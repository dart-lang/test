// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stack_trace/stack_trace.dart';

import 'group_entry.dart';
import 'metadata.dart';
import 'suite_platform.dart';
import 'test.dart';
import 'test_location.dart';

/// A group contains one or more tests and subgroups.
///
/// It includes metadata that applies to all contained tests.
class Group implements GroupEntry {
  @override
  final String name;

  @override
  Group? parent;

  @override
  final Metadata metadata;

  @override
  final Trace? trace;

  @override
  final TestLocation? location;

  /// The children of this group.
  final List<GroupEntry> entries;

  /// Returns a new root-level group.
  Group.root(Iterable<GroupEntry> entries, {Metadata? metadata})
    : this('', entries, metadata: metadata);

  /// A test to run before all tests in the group.
  ///
  /// This is `null` if no `setUpAll` callbacks were declared.
  final Test? setUpAll;

  /// A test to run after all tests in the group.
  ///
  /// This is `null` if no `tearDown` callbacks were declared.
  final Test? tearDownAll;

  /// The number of tests (recursively) in this group.
  int get testCount {
    if (_testCount != null) return _testCount!;
    _testCount = entries.fold<int>(
      0,
      (count, entry) => count + (entry is Group ? entry.testCount : 1),
    );
    return _testCount!;
  }

  int? _testCount;

  Group(
    this.name,
    Iterable<GroupEntry> entries, {
    Metadata? metadata,
    this.trace,
    this.location,
    this.setUpAll,
    this.tearDownAll,
  }) : entries = List<GroupEntry>.unmodifiable(entries),
       metadata = metadata ?? Metadata() {
    for (var entry in entries) {
      assert(entry.parent == null);
      entry.parent = this;
    }
    assert(setUpAll?.parent == null);
    setUpAll?.parent = this;
    assert(tearDownAll?.parent == null);
    tearDownAll?.parent = this;
  }

  @override
  Group? forPlatform(SuitePlatform platform) {
    if (!metadata.testOn.evaluate(platform)) return null;
    var newMetadata = metadata.forPlatform(platform);
    var filtered = _map((entry) => entry.forPlatform(platform));
    if (filtered.isEmpty && entries.isNotEmpty) return null;
    return Group(
      name,
      filtered,
      metadata: newMetadata,
      trace: trace,
      location: location,
      setUpAll: setUpAll?.forPlatform(platform),
      tearDownAll: tearDownAll?.forPlatform(platform),
    );
  }

  @override
  Group? filter(bool Function(Test) callback) {
    var filtered = _map((entry) => entry.filter(callback));
    if (filtered.isEmpty && entries.isNotEmpty) return null;
    return Group(
      name,
      filtered,
      metadata: metadata,
      trace: trace,
      location: location,
      // Always clone these because they are being re-parented.
      setUpAll: setUpAll?.clone(),
      tearDownAll: tearDownAll?.clone(),
    );
  }

  @override
  Group? clone() {
    var entries = _map((entry) => entry.clone());
    return Group(
      name,
      entries,
      metadata: metadata,
      trace: trace,
      location: location,
      // Always clone these because they are being re-parented.
      setUpAll: setUpAll?.clone(),
      tearDownAll: tearDownAll?.clone(),
    );
  }

  /// Returns the entries of this group mapped using [callback].
  ///
  /// Any `null` values returned by [callback] will be removed.
  List<GroupEntry> _map(GroupEntry? Function(GroupEntry) callback) {
    return entries
        .map((entry) => callback(entry))
        .whereType<GroupEntry>()
        .toList();
  }
}
