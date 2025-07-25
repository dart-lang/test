// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:boolean_selector/boolean_selector.dart';
import 'package:glob/glob.dart';
import 'package:test/test.dart';
import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/group_entry.dart';
import 'package:test_api/src/backend/live_test.dart';
import 'package:test_api/src/backend/platform_selector.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/state.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_core/src/runner/application_exception.dart';
import 'package:test_core/src/runner/compiler_selection.dart';
import 'package:test_core/src/runner/configuration.dart';
import 'package:test_core/src/runner/configuration/custom_runtime.dart';
import 'package:test_core/src/runner/configuration/runtime_settings.dart';
import 'package:test_core/src/runner/engine.dart';
import 'package:test_core/src/runner/load_suite.dart';
import 'package:test_core/src/runner/plugin/environment.dart';
import 'package:test_core/src/runner/runner_suite.dart';
import 'package:test_core/src/runner/runtime_selection.dart';
import 'package:test_core/src/runner/suite.dart';

/// A dummy suite platform to use for testing suites.
final suitePlatform = SuitePlatform(Runtime.vm, compiler: null);

// The last state change detected via [expectStates].
State? _lastState;

/// Asserts that exactly [states] will be emitted via [liveTest.onStateChange].
///
/// The most recent emitted state is stored in [_lastState].
void expectStates(LiveTest liveTest, Iterable<State> statesIter) {
  var states = Queue.of(statesIter);
  liveTest.onStateChange.listen(
    expectAsync1(
      (state) {
        _lastState = state;
        expect(state, equals(states.removeFirst()));
      },
      count: states.length,
      max: states.length,
    ),
  );
}

/// Asserts that errors will be emitted via [liveTest.onError] that match
/// [validators], in order.
void expectErrors(
  LiveTest liveTest,
  Iterable<void Function(Object)> validatorsIter,
) {
  var validators = Queue.of(validatorsIter);
  liveTest.onError.listen(
    expectAsync1(
      (error) {
        validators.removeFirst()(error.error);
      },
      count: validators.length,
      max: validators.length,
    ),
  );
}

/// Asserts that [liveTest] will have a single failure with message `"oh no"`.
void expectSingleFailure(LiveTest liveTest) {
  expectStates(liveTest, [
    const State(Status.running, Result.success),
    const State(Status.complete, Result.failure),
  ]);

  expectErrors(liveTest, [
    (error) {
      expect(_lastState!.status, equals(Status.complete));
      expect(error, _isTestFailure('oh no'));
    },
  ]);
}

/// Returns a matcher that matches a [TestFailure] with the given [message].
///
/// [message] can be a string or a [Matcher].
Matcher _isTestFailure(Object message) => const TypeMatcher<TestFailure>()
    .having((e) => e.message, 'message', message);

/// Returns a matcher that matches a [ApplicationException] with the given
/// [message].
///
/// [message] can be a string or a [Matcher].
Matcher isApplicationException(Object message) =>
    const TypeMatcher<ApplicationException>().having(
      (e) => e.message,
      'message',
      message,
    );

/// Asserts that [liveTest] has completed and passed.
///
/// If the test had any errors, they're surfaced nicely into the outer test.
void expectTestPassed(LiveTest liveTest) {
  // Since the test is expected to pass, we forward any current or future errors
  // to the outer test, because they're definitely unexpected.
  for (var error in liveTest.errors) {
    registerException(error.error, error.stackTrace);
  }
  liveTest.onError.listen((error) {
    registerException(error.error, error.stackTrace);
  });

  expect(liveTest.state.status, equals(Status.complete));
  expect(liveTest.state.result, equals(Result.success));
}

/// Asserts that [liveTest] failed with a single [TestFailure] whose message
/// matches [message].
void expectTestFailed(LiveTest liveTest, Object message) {
  expect(liveTest.state.status, equals(Status.complete));
  expect(liveTest.state.result, equals(Result.failure));
  expect(liveTest.errors, hasLength(1));
  expect(liveTest.errors.first.error, _isTestFailure(message));
}

/// Runs [body] with a declarer and returns the declared entries.
List<GroupEntry> declare(void Function() body) {
  var declarer = Declarer()..declare(body);
  return declarer.build().entries;
}

/// Runs [body] with a declarer and returns an engine that runs those tests.
Engine declareEngine(
  void Function() body, {
  bool runSkipped = false,
  String? coverage,
  bool stopOnFirstFailure = false,
}) {
  var declarer = Declarer()..declare(body);
  return Engine.withSuites(
    [
      RunnerSuite(
        const PluginEnvironment(),
        SuiteConfiguration.runSkipped(runSkipped),
        declarer.build(),
        suitePlatform,
      ),
    ],
    coverage: coverage,
    stopOnFirstFailure: stopOnFirstFailure,
  );
}

/// Returns a [RunnerSuite] with a default environment and configuration.
RunnerSuite runnerSuite(Group root) => RunnerSuite(
  const PluginEnvironment(),
  SuiteConfiguration.empty,
  root,
  suitePlatform,
);

/// Returns a [LoadSuite] with a default configuration.
LoadSuite loadSuite(String name, FutureOr<RunnerSuite> Function() body) =>
    LoadSuite(name, SuiteConfiguration.empty, suitePlatform, body);

SuiteConfiguration suiteConfiguration({
  bool? allowDuplicateTestNames,
  bool? allowTestRandomization,
  bool? jsTrace,
  bool? runSkipped,
  Iterable<String>? dart2jsArgs,
  String? precompiledPath,
  Iterable<CompilerSelection>? compilerSelections,
  Iterable<RuntimeSelection>? runtimes,
  Map<BooleanSelector, SuiteConfiguration>? tags,
  Map<PlatformSelector, SuiteConfiguration>? onPlatform,
  bool? ignoreTimeouts,

  // Test-level configuration
  Timeout? timeout,
  bool? verboseTrace,
  bool? chainStackTraces,
  bool? skip,
  int? retry,
  String? skipReason,
  PlatformSelector? testOn,
  Iterable<String>? addTags,
}) => SuiteConfiguration(
  allowDuplicateTestNames: allowDuplicateTestNames,
  allowTestRandomization: allowTestRandomization,
  jsTrace: jsTrace,
  runSkipped: runSkipped,
  dart2jsArgs: dart2jsArgs,
  precompiledPath: precompiledPath,
  compilerSelections: compilerSelections,
  runtimes: runtimes,
  tags: tags,
  onPlatform: onPlatform,
  ignoreTimeouts: ignoreTimeouts,
  timeout: timeout,
  verboseTrace: verboseTrace,
  chainStackTraces: chainStackTraces,
  skip: skip,
  retry: retry,
  skipReason: skipReason,
  testOn: testOn,
  addTags: addTags,
);

Configuration configuration({
  bool? help,
  String? customHtmlTemplatePath,
  bool? version,
  bool? pauseAfterLoad,
  bool? debug,
  bool? color,
  String? configurationPath,
  String? reporter,
  Map<String, String>? fileReporters,
  String? coverage,
  int? concurrency,
  int? shardIndex,
  int? totalShards,
  Map<String, Set<TestSelection>>? testSelections,
  Iterable<String>? foldTraceExcept,
  Iterable<String>? foldTraceOnly,
  Glob? filename,
  Iterable<String>? chosenPresets,
  Map<String, Configuration>? presets,
  Map<String, RuntimeSettings>? overrideRuntimes,
  Map<String, CustomRuntime>? defineRuntimes,
  bool? noRetry,
  bool? ignoreTimeouts,

  // Suite-level configuration
  bool? allowDuplicateTestNames,
  bool? allowTestRandomization,
  bool? jsTrace,
  bool? runSkipped,
  Iterable<String>? dart2jsArgs,
  String? precompiledPath,
  Iterable<Pattern>? globalPatterns,
  Iterable<CompilerSelection>? compilerSelections,
  Iterable<RuntimeSelection>? runtimes,
  BooleanSelector? includeTags,
  BooleanSelector? excludeTags,
  Map<BooleanSelector, SuiteConfiguration>? tags,
  Map<PlatformSelector, SuiteConfiguration>? onPlatform,
  int? testRandomizeOrderingSeed,

  // Test-level configuration
  Timeout? timeout,
  bool? verboseTrace,
  bool? chainStackTraces,
  bool? skip,
  int? retry,
  String? skipReason,
  PlatformSelector? testOn,
  Iterable<String>? addTags,
}) => Configuration(
  help: help,
  customHtmlTemplatePath: customHtmlTemplatePath,
  version: version,
  pauseAfterLoad: pauseAfterLoad,
  debug: debug,
  color: color,
  configurationPath: configurationPath,
  reporter: reporter,
  fileReporters: fileReporters,
  coverage: coverage,
  concurrency: concurrency,
  shardIndex: shardIndex,
  totalShards: totalShards,
  testSelections: testSelections,
  foldTraceExcept: foldTraceExcept,
  foldTraceOnly: foldTraceOnly,
  filename: filename,
  chosenPresets: chosenPresets,
  presets: presets,
  overrideRuntimes: overrideRuntimes,
  defineRuntimes: defineRuntimes,
  noRetry: noRetry,
  ignoreTimeouts: ignoreTimeouts,
  allowDuplicateTestNames: allowDuplicateTestNames,
  allowTestRandomization: allowTestRandomization,
  jsTrace: jsTrace,
  runSkipped: runSkipped,
  dart2jsArgs: dart2jsArgs,
  precompiledPath: precompiledPath,
  globalPatterns: globalPatterns,
  compilerSelections: compilerSelections,
  runtimes: runtimes,
  includeTags: includeTags,
  excludeTags: excludeTags,
  tags: tags,
  onPlatform: onPlatform,
  testRandomizeOrderingSeed: testRandomizeOrderingSeed,
  stopOnFirstFailure: false,
  timeout: timeout,
  verboseTrace: verboseTrace,
  chainStackTraces: chainStackTraces,
  skip: skip,
  retry: retry,
  skipReason: skipReason,
  testOn: testOn,
  addTags: addTags,
);
