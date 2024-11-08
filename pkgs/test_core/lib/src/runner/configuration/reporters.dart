// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import '../../util/io.dart';
import '../configuration.dart';
import '../engine.dart';
import '../reporter.dart';
import '../reporter/compact.dart';
import '../reporter/expanded.dart';
import '../reporter/failures_only.dart';
import '../reporter/github.dart';
import '../reporter/json.dart';

/// Constructs a reporter for the provided engine with the provided
/// configuration.
typedef ReporterFactory = Reporter Function(Configuration, Engine, StringSink);

/// Container for a reporter description and corresponding factory.
class ReporterDetails {
  final String description;
  final ReporterFactory factory;
  ReporterDetails(this.description, this.factory);
}

/// All reporters and their corresponding details.
final UnmodifiableMapView<String, ReporterDetails> allReporters =
    UnmodifiableMapView<String, ReporterDetails>(_allReporters);

final _allReporters = <String, ReporterDetails>{
  'expanded': ReporterDetails(
      'A separate line for each update.',
      (config, engine, sink) => ExpandedReporter.watch(engine, sink,
          color: config.color,
          printPath: config.testSelections.length > 1 ||
              Directory(config.testSelections.keys.single).existsSync(),
          printPlatform: config.suiteDefaults.runtimes.length > 1 ||
              config.suiteDefaults.compilerSelections != null)),
  'compact': ReporterDetails(
      'A single line, updated continuously.',
      (config, engine, sink) => CompactReporter.watch(engine, sink,
          color: config.color,
          printPath: config.testSelections.length > 1 ||
              Directory(config.testSelections.keys.single).existsSync(),
          printPlatform: config.suiteDefaults.runtimes.length > 1 ||
              config.suiteDefaults.compilerSelections != null)),
  'failures-only': ReporterDetails(
      'A separate line for failing tests with no output for passing tests',
      (config, engine, sink) => FailuresOnlyReporter.watch(engine, sink,
          color: config.color,
          printPath: config.testSelections.length > 1 ||
              Directory(config.testSelections.keys.single).existsSync(),
          printPlatform: config.suiteDefaults.runtimes.length > 1 ||
              config.suiteDefaults.compilerSelections != null)),
  'github': ReporterDetails(
      'A custom reporter for GitHub Actions '
      '(the default reporter when running on GitHub Actions).',
      (config, engine, sink) => GithubReporter.watch(engine, sink,
          printPath: config.testSelections.length > 1 ||
              Directory(config.testSelections.keys.single).existsSync(),
          printPlatform: config.suiteDefaults.runtimes.length > 1 ||
              config.suiteDefaults.compilerSelections != null)),
  'json': ReporterDetails(
      'A machine-readable format (see '
      'https://dart.dev/go/test-docs/json_reporter.md).',
      (config, engine, sink) =>
          JsonReporter.watch(engine, sink, isDebugRun: config.debug)),
  'silent': ReporterDetails(
      'A reporter with no output. '
      'May be useful when only the exit code is meaningful.',
      (config, engine, sink) => SilentReporter()),
};

final defaultReporter = inTestTests
    ? 'expanded'
    : inGithubContext
        ? 'github'
        : canUseSpecialChars
            ? 'compact'
            : 'expanded';

/// **Do not call this function without express permission from the test package
/// authors**.
///
/// This globally registers a reporter.
void registerReporter(String name, ReporterDetails reporterDetails) {
  _allReporters[name] = reporterDetails;
}
