// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Runs every example under `example/` and checks that the failures it
/// produces match the expected failures recorded in the example's comments.
///
/// Each example demonstrates one or more matchers that fail. A failing
/// expectation is the last statement of its test, and the failure it produces
/// is recorded immediately below it in a comment block starting with
/// `// Expected:`. This test keeps those comment blocks honest.
///
/// The examples are expected to fail when run with the test runner -
/// demonstrating the failure is the point. This test asserts that they fail in
/// exactly the documented way.
///
/// All examples are run together in a single `dart test` invocation so that the
/// runner compiles them incrementally using one `frontend_server` instance and
/// runs the suites concurrently. The JSON reporter associates each failure with
/// the suite it came from.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final examples = _exampleFiles();
  late final Map<String, List<String>> failures;

  setUpAll(() async {
    failures = await _failures(examples);
  });

  for (final example in examples) {
    test(example.path, () {
      final source = example.readAsStringSync();
      expect(
        failures[example.path],
        equals(_recordedFailures(source)),
        reason:
            'the `// Expected:` comments in ${example.path} must match the '
            'failures it produces. Run it with '
            '`dart test ${example.path}` to see the current failures.',
      );
    });
  }
}

/// Every `.dart` file under `example/`, in a stable order.
List<File> _exampleFiles() =>
    Directory('example')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// The failures recorded in the comment blocks of [source], in the order they
/// appear.
///
/// A recorded failure is the run of `//` comment lines that ends a test body,
/// so it is the last thing before the closing `});`. Not every failure message
/// starts with `Expected:` - `fail` and the future matchers report a bare
/// message - so the position in the test is what identifies the block rather
/// than its content.
List<String> _recordedFailures(String source) {
  final failures = <String>[];
  var block = <String>[];
  for (final line in LineSplitter.split(source)) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) {
      block.add(trimmed == '//' ? '' : trimmed.substring('// '.length));
      continue;
    }
    // The run ended. It is a recorded failure only if it closes a test body.
    if (block.isNotEmpty && trimmed == '});') {
      failures.add(block.join('\n'));
    }
    block = [];
  }
  return failures;
}

/// Runs all of [examples] with the test runner and returns, for each one, the
/// failure message from each of its tests that failed, in the order the tests
/// were declared.
Future<Map<String, List<String>>> _failures(List<File> examples) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'test',
    for (final example in examples) example.path,
    '--reporter',
    'json',
  ]);
  // The suites run concurrently so their events interleave, but every test
  // names the suite it belongs to, and the tests within a suite start in the
  // order they were declared.
  final suitePaths = <int, String>{};
  final testSuites = <int, int>{};
  final testNames = <int, String>{};
  final testOrder = <int>[];
  final errors = <int, String>{};
  for (final line in LineSplitter.split(result.stdout as String)) {
    if (!line.startsWith('{')) continue;
    final event = jsonDecode(line);
    if (event is! Map) continue;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite'] as Map;
        suitePaths[suite['id'] as int] = suite['path'] as String;
      case 'testStart':
        final test = event['test'] as Map;
        final id = test['id'] as int;
        testSuites[id] = test['suiteID'] as int;
        testNames[id] = test['name'] as String;
        testOrder.add(id);
      case 'error':
        // Only the first error for a test is the failure it demonstrates.
        // Every message ends with a newline, which a comment block cannot
        // represent, so drop exactly that one trailing newline.
        errors.putIfAbsent(event['testID'] as int, () {
          final error = event['error'] as String;
          return error.endsWith('\n')
              ? error.substring(0, error.length - 1)
              : error;
        });
    }
  }
  final failures = {for (final example in examples) example.path: <String>[]};
  for (final id in testOrder) {
    final path = suitePaths[testSuites[id]!]!;
    // A test named `loading <path>` is the implicit suite load. An error there
    // means the example did not compile or run at all.
    if (testNames[id]!.startsWith('loading ')) {
      if (errors[id] case final error?) {
        throw StateError('$path failed to load:\n$error');
      }
      continue;
    }
    if (errors[id] case final error?) failures[path]!.add(error);
  }
  return failures;
}
