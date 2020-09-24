// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:path/path.dart' as p;
import 'package:test_api/backend.dart'; //ignore: deprecated_member_use
import 'package:test_api/src/backend/declarer.dart'; //ignore: implementation_imports
import 'package:test_api/src/backend/group.dart'; //ignore: implementation_imports
import 'package:test_api/src/backend/group_entry.dart'; //ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; //ignore: implementation_imports
import 'package:test_api/src/frontend/utils.dart'; // ignore: implementation_imports
import 'package:test_api/src/utils.dart'; // ignore: implementation_imports

import 'runner/configuration.dart';
import 'runner/engine.dart';
import 'runner/plugin/environment.dart';
import 'runner/reporter.dart';
import 'runner/reporter/expanded.dart';
import 'runner/runner_suite.dart';
import 'runner/suite.dart';
import 'util/print_sink.dart';

/// Run all test cases declared in [testMain].
///
/// Test suite level metadata defined in annotations is not read. No filtering
/// is applied except for the filtering defined by `solo` or `skip` arguments to
/// `group` and `test`.
Future<bool> directRunTests(FutureOr<void> Function() testMain,
        {Reporter Function(Engine)? reporterFactory}) =>
    _directRunTests(testMain, reporterFactory: reporterFactory);

/// Run a single test declared in [testMain].
///
/// There must be exactly one test defined with the name [testName]. Note that
/// not all tests and groups are checked, so a test case that may not be
/// intended to be run (due to a `solo` on a different test) may still be run
/// with this API. Only the test names returned by [enumerateTestCases] should
/// be used.
Future<bool> directRunSingleTest(
        FutureOr<void> Function() testMain, String testName,
        {Reporter Function(Engine)? reporterFactory}) =>
    _directRunTests(testMain,
        reporterFactory: reporterFactory, runSingleTestByName: testName);

Future<bool> _directRunTests(FutureOr<void> Function() testMain,
    {Reporter Function(Engine)? reporterFactory,
    String? runSingleTestByName}) async {
  reporterFactory ??= (engine) => ExpandedReporter.watch(engine, PrintSink(),
      color: Configuration.empty.color, printPath: false, printPlatform: false);
  final declarer = Declarer(filterToSingleTestName: runSingleTestByName);
  await declarer.declare(testMain);

  await pumpEventQueue();

  final suite = RunnerSuite(const PluginEnvironment(), SuiteConfiguration.empty,
      declarer.build(), SuitePlatform(Runtime.vm, os: currentOSGuess),
      path: p.prettyUri(Uri.base));

  final engine = Engine()
    ..suiteSink.add(suite)
    ..suiteSink.close();

  reporterFactory(engine);

  final success = await runZoned(() => Invoker.guard(engine.run),
      zoneValues: {#test.declarer: declarer});

  if (runSingleTestByName != null) {
    final testCount = engine.liveTests.length;
    if (testCount > 1) {
      throw DuplicateTestNameException(runSingleTestByName);
    }
    if (testCount == 0) {
      throw MissingTestException(runSingleTestByName);
    }
  }
  return success!;
}

/// Return the names of all tests declared by [testMain].
///
/// Test names declared must be unique. If any test repeats the name of a prior
/// test a [DuplicateTestNameException] will be thrown.
///
/// Skipped tests are ignored.
Future<Iterable<String>> enumerateTestCases(
    FutureOr<void> Function() testMain) async {
  final declarer = Declarer();
  await declarer.declare(testMain);

  await pumpEventQueue();

  final toVisit = Queue<GroupEntry>.of([declarer.build()]);
  final allTestNames = <String>{};
  while (toVisit.isNotEmpty) {
    final current = toVisit.removeLast();
    if (current is Group) {
      toVisit.addAll(current.entries.reversed);
    } else if (current is Test) {
      if (current.metadata.skip) continue;
      if (!allTestNames.add(current.name)) {
        throw DuplicateTestNameException(current.name);
      }
    } else {
      throw StateError('Unandled Group Entry: ${current.runtimeType}');
    }
  }
  return allTestNames;
}

/// An exception thrown when two test cases in the same test suite (same `main`)
/// have an identical name.
class DuplicateTestNameException implements Exception {
  final String name;
  DuplicateTestNameException(this.name);

  @override
  String toString() => 'A test with the name "$name" was already declared. '
      'Test cases must have unique names.';
}

/// An exception thrown when a specific test was requested by name that does not
/// exist.
class MissingTestException implements Exception {
  final String name;
  MissingTestException(this.name);

  @override
  String toString() =>
      'A test with the name "$name" was not declared in the test suite.';
}
