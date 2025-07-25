// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_core/src/runner/version.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// Asserts that the outputs from running tests with a JSON reporter match the
/// given expectations.
///
/// Verifies that [outputLines] matches each set of matchers in [expected],
/// includes the [testPid] from the test process, and ends with [done].
Future<void> expectJsonReport(
  List<String> outputLines,
  int testPid,
  List<List<Object /*Map|Matcher*/>> expected,
  Map<Object, Object> done,
) async {
  // Ensure the output is of the same length, including start, done and all
  // suites messages.
  expect(
    outputLines,
    hasLength(expected.fold<int>(3, (int a, m) => a + m.length)),
  );

  final decoded = [
    for (final line in outputLines)
      (jsonDecode(line) as Map)
        ..remove('time')
        ..remove('stackTrace'),
  ];

  // Should contain all suites message.
  expect(decoded, containsAll([_allSuitesJson()]));

  // A single start event is emitted first.
  final start = {
    'type': 'start',
    'protocolVersion': '0.1.1',
    'runnerVersion': testVersion,
    'pid': testPid,
  };
  expect(decoded.first, equals(start));

  // A single done event is emitted last.
  expect(decoded.last, equals(done));

  for (var value in expected) {
    expect(decoded, containsAllInOrder(value));
  }
}

/// Returns the event emitted by the JSON reporter providing information about
/// all suites.
///
/// The [count] defaults to 1.
Map<String, Object> _allSuitesJson({int count = 1}) => {
  'type': 'allSuites',
  'count': count,
};

/// Returns the event emitted by the JSON reporter indicating that a suite has
/// begun running.
///
/// The [platform] defaults to `'vm'`.
/// The [path] defaults to `equals('test.dart')`.
Map<String, Object> suiteJson(
  int id, {
  String platform = 'vm',
  Matcher? path,
}) => {
  'type': 'suite',
  'suite': {'id': id, 'platform': platform, 'path': path ?? 'test.dart'},
};

/// Returns the event emitted by the JSON reporter indicating that a group has
/// begun running.
///
/// If [skip] is `true`, the group is expected to be marked as skipped without a
/// reason. If it's a [String], the group is expected to be marked as skipped
/// with that reason.
///
/// The [testCount] parameter indicates the number of tests in the group. It
/// defaults to 1.
Map<String, Object> groupJson(
  int id, {
  String? name,
  int? suiteID,
  int? parentID,
  Object? skip,
  int? testCount,
  String? url,
  int? line,
  int? column,
}) {
  if ((line == null) != (column == null)) {
    throw ArgumentError(
      'line and column must either both be null or both be passed',
    );
  }

  url ??=
      line == null ? null : p.toUri(p.join(d.sandbox, 'test.dart')).toString();
  return {
    'type': 'group',
    'group': {
      'id': id,
      'name': name ?? '',
      'suiteID': suiteID ?? 0,
      'parentID': parentID,
      'metadata': _metadataJson(skip: skip),
      'testCount': testCount ?? 1,
      'line': line,
      'column': column,
      'url': url,
    },
  };
}

/// Returns the event emitted by the JSON reporter indicating that a test has
/// begun running.
///
/// If [groupIDs] is passed, it's the IDs of groups containing this test. If
/// [skip] is `true`, the test is expected to be marked as skipped without a
/// reason. If it's a [String], the test is expected to be marked as skipped
/// with that reason.
Map<String, Object> testStartJson(
  int id,
  Object /*String|Matcher*/ name, {
  int? suiteID,
  Iterable<int>? groupIDs,
  int? line,
  int? column,
  String? url,
  Object? skip,
  int? rootLine,
  int? rootColumn,
  String? rootUrl,
}) {
  if ((line == null) != (column == null)) {
    throw ArgumentError(
      'line and column must either both be null or both be passed',
    );
  }

  url ??=
      line == null ? null : p.toUri(p.join(d.sandbox, 'test.dart')).toString();
  return {
    'type': 'testStart',
    'test': {
      'id': id,
      'name': name,
      'suiteID': suiteID ?? 0,
      'groupIDs': groupIDs ?? [2],
      'metadata': _metadataJson(skip: skip),
      'line': line,
      'column': column,
      'url': url,
      if (rootLine != null) 'root_line': rootLine,
      if (rootColumn != null) 'root_column': rootColumn,
      if (rootUrl != null) 'root_url': rootUrl,
    },
  };
}

/// Returns the event emitted by the JSON reporter indicating that a test
/// printed [message].
Matcher printJson(
  int id,
  dynamic /*String|Matcher*/ message, {
  String type = 'print',
}) => allOf(
  hasLength(4),
  containsPair('type', 'print'),
  containsPair('testID', id),
  containsPair('message', message),
  containsPair('messageType', type),
);

/// Returns the event emitted by the JSON reporter indicating that a test
/// emitted [error].
///
/// The [isFailure] parameter indicates whether the error was a [TestFailure] or
/// not.
Map<String, Object> errorJson(int id, String error, {bool isFailure = false}) =>
    {'type': 'error', 'testID': id, 'error': error, 'isFailure': isFailure};

/// Returns the event emitted by the JSON reporter indicating that a test
/// finished.
///
/// The [result] parameter indicates the result of the test. It defaults to
/// `"success"`.
///
/// The [hidden] parameter indicates whether the test should not be displayed
/// after finishing. The [skipped] parameter indicates whether the test was
/// skipped.
Map<String, Object> testDoneJson(
  int id, {
  String result = 'success',
  bool hidden = false,
  bool skipped = false,
}) => {
  'type': 'testDone',
  'testID': id,
  'result': result,
  'hidden': hidden,
  'skipped': skipped,
};

/// Returns the event emitted by the JSON reporter indicating that the entire
/// run finished.
Map<String, Object> doneJson({bool success = true}) => {
  'type': 'done',
  'success': success,
};

/// Returns the serialized metadata corresponding to [skip].
Map<String, Object?> _metadataJson({Object? skip}) => {
  'skip': skip == true || skip is String,
  'skipReason': skip is String ? skip : null,
};
