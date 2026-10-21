// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:test_api/backend.dart';
import 'package:test_api/src/backend/state.dart';
import 'package:test_api/src/backend/util/pretty_print.dart';

import '../engine.dart';
import '../load_suite.dart';
import '../reporter.dart';
import 'attempt_counter.dart';

/// A reporter that prints test output using formatting for Github Actions.
///
/// See
/// https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
/// for a description of the output format, and
/// https://github.com/dart-lang/test/issues/1415 for discussions about this
/// implementation.
class GithubReporter implements Reporter {
  /// The engine used to run the tests.
  final Engine _engine;

  /// Whether the path to each test's suite should be printed.
  final bool _printPath;

  /// Whether the platform each test is running on should be printed.
  final bool _printPlatform;

  /// Whether the reporter is paused.
  var _paused = false;

  /// The set of all subscriptions to various streams.
  final _subscriptions = <StreamSubscription>{};

  final StringSink _sink;

  /// The messages and errors from each test that hasn't completed yet, in the
  /// order they were emitted.
  ///
  /// Each entry is either a [Message] or an [AsyncError]. Keeping them in one
  /// list preserves the order of output across retries, so that a `Retry:`
  /// message follows the error that caused it.
  final Map<LiveTest, List<Object>> _testOutput = {};

  /// The number of attempts each test has started, for tests with `retry`.
  final _attempts = AttemptCounter();

  final Set<LiveTest> _completedTests = {};

  final List<LiveTest> _skippedTests = [];

  /// Whether a `::group::` for passing tests is currently open.
  var _inPassingGroup = false;

  /// Watches the tests run by [engine] and prints their results as JSON.
  static GithubReporter watch(
    Engine engine,
    StringSink sink, {
    required bool printPath,
    required bool printPlatform,
  }) => GithubReporter._(engine, sink, printPath, printPlatform);

  GithubReporter._(
    this._engine,
    this._sink,
    this._printPath,
    this._printPlatform,
  ) {
    _subscriptions.add(_engine.onTestStarted.listen(_onTestStarted));
    _subscriptions.add(_engine.success.asStream().listen(_onDone));

    // Add a spacer between pre-test output and the test results.
    _sink.writeln();
  }

  @override
  void pause() {
    if (_paused) return;
    _paused = true;

    for (var subscription in _subscriptions) {
      subscription.pause();
    }
  }

  @override
  void resume() {
    if (!_paused) return;
    _paused = false;

    for (var subscription in _subscriptions) {
      subscription.resume();
    }
  }

  void _cancel() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// A callback called when the engine begins running [liveTest].
  void _onTestStarted(LiveTest liveTest) {
    _subscriptions.add(_attempts.watch(liveTest));

    // Convert the future to a stream so that the subscription can be paused or
    // canceled.
    _subscriptions.add(
      liveTest.onComplete.asStream().listen((_) => _onComplete(liveTest)),
    );

    _subscriptions.add(
      liveTest.onError.listen((error) => _onError(liveTest, error)),
    );

    // Collect messages from tests as they are emitted.
    _subscriptions.add(
      liveTest.onMessage.listen((message) {
        if (_completedTests.contains(liveTest) &&
            liveTest.state.result != Result.skipped) {
          // The test has already completed and its previous messages were
          // written out; ensure this post-completion output is not lost.
          if (_inPassingGroup) {
            _sink.writeln(_GithubMarkup.endGroup);
            _inPassingGroup = false;
          }
          _sink.writeln(message.text);
        } else {
          _testOutput.putIfAbsent(liveTest, () => []).add(message);
        }
      }),
    );
  }

  String _testName(LiveTest test) {
    var name = test.test.name;
    if (test.suite is! LoadSuite) {
      if (_printPath && test.suite.path != null) {
        name = '${test.suite.path}: $name';
      }
    }
    if (_printPlatform) {
      name =
          '[${test.suite.platform.runtime.name}, '
          '${test.suite.platform.compiler.name}] $name';
    }
    return name;
  }

  /// A callback called when [liveTest] finishes running.
  void _onComplete(LiveTest test) {
    final errors = test.errors;
    final output = _testOutput[test] ?? const <Object>[];
    final skipped = test.state.result == Result.skipped;
    final loadSuite = test.suite is LoadSuite;
    final synthetic =
        loadSuite ||
        test.individualName == '(setUpAll)' ||
        test.individualName == '(tearDownAll)';

    // Mark this test as having completed.
    _completedTests.add(test);

    // Don't emit any info for loadSuite, setUpAll, or tearDownAll tests
    // unless they contain errors or other info.
    if (synthetic && (errors.isEmpty && output.isEmpty)) {
      return;
    }

    if (skipped && errors.isEmpty) {
      _skippedTests.add(test);
      return;
    }

    // For now, we use the same icon for both tests and test-like structures
    // (loadSuite, setUpAll, tearDownAll).
    final defaultIcon = synthetic ? _GithubMarkup.passed : _GithubMarkup.passed;
    final name = _testName(test);

    if (errors.isEmpty) {
      if (!_inPassingGroup) {
        _sink.writeln(_GithubMarkup.startGroup('✅ Passing tests'));
        _inPassingGroup = true;
      }
      _sink.writeln('$defaultIcon $name');
      _writeOutput(output);
    } else {
      if (_inPassingGroup) {
        _sink.writeln(_GithubMarkup.endGroup);
        _inPassingGroup = false;
      }
      // A test that passed on retry still has the errors from its failed
      // attempts. Show them, but don't present the test as a failure.
      final attempts = _attempts.attemptsFor(test);
      final maxAttempts = test.test.metadata.retry + 1;
      final String title;
      if (_engine.flaky.contains(test)) {
        // The attempt count is only missing if the reporter missed the test's
        // first state change, for example while paused.
        title = attempts == 0
            ? '${_GithubMarkup.flaky} $name (passed on retry)'
            : '${_GithubMarkup.flaky} $name '
                  '(passed on attempt $attempts of $maxAttempts)';
      } else if (attempts > 1) {
        title =
            '${_GithubMarkup.failed} $name (failed after $attempts attempts)';
      } else {
        title = '${_GithubMarkup.failed} $name (failed)';
      }
      _sink.writeln(_GithubMarkup.startGroup(title));
      _writeOutput(output);
      _sink.writeln(_GithubMarkup.endGroup);
    }
  }

  /// Writes the messages and errors in [output] in the order they were
  /// emitted.
  void _writeOutput(List<Object> output) {
    for (var entry in output) {
      if (entry is Message) {
        _sink.writeln(entry.text);
      } else if (entry is AsyncError) {
        _sink.writeln('${entry.error}');
        _sink.writeln(entry.stackTrace.toString().trimRight());
      }
    }
  }

  /// A callback called when [test] throws [error].
  void _onError(LiveTest test, AsyncError error) {
    if (!_completedTests.contains(test)) {
      _testOutput.putIfAbsent(test, () => []).add(error);
      return;
    }

    final prefix = _GithubMarkup.failed;
    final statusSuffix = ' (failed after test completion)';
    final name = _testName(test);

    if (_inPassingGroup) {
      _sink.writeln(_GithubMarkup.endGroup);
      _inPassingGroup = false;
    }
    _sink.writeln(_GithubMarkup.startGroup('$prefix $name$statusSuffix'));
    _sink.writeln('${error.error}');
    _sink.writeln(error.stackTrace.toString().trimRight());
    _sink.writeln(_GithubMarkup.endGroup);
  }

  void _onDone(bool? success) {
    _cancel();

    if (_inPassingGroup) {
      _sink.writeln(_GithubMarkup.endGroup);
      _inPassingGroup = false;
    }

    if (_skippedTests.isNotEmpty) {
      _sink.writeln(_GithubMarkup.startGroup('⏭️ Skipped tests'));
      for (var test in _skippedTests) {
        final name = _testName(test);
        _sink.writeln('${_GithubMarkup.skipped} $name (skipped)');
        _writeOutput(_testOutput[test] ?? const <Object>[]);
      }
      _sink.writeln(_GithubMarkup.endGroup);
    }

    _sink.writeln();

    // Flaky tests are reported separately from passing tests, so that the
    // counts in the summary don't overlap.
    final flaky = _engine.flaky;
    final passedCount = _engine.passed.where((t) => !flaky.contains(t)).length;
    final hadFailures = _engine.failed.isNotEmpty;
    final message = StringBuffer(
      '$passedCount ${pluralize('test', passedCount)} passed',
    );
    if (_engine.failed.isNotEmpty) {
      message.write(', ${_engine.failed.length} failed');
    }
    if (flaky.isNotEmpty) {
      message.write(', ${flaky.length} flaky');
    }
    if (_engine.skipped.isNotEmpty) {
      message.write(', ${_engine.skipped.length} skipped');
    }
    message.write('.');
    _sink.writeln(
      hadFailures
          ? _GithubMarkup.error(message.toString())
          : flaky.isNotEmpty
          ? _GithubMarkup.warning(message.toString())
          : '${_GithubMarkup.success} $message',
    );
  }
}

abstract class _GithubMarkup {
  // Char sets avilable at https://www.compart.com/en/unicode/.
  static const String passed = '✅';
  static const String skipped = '⏭️';
  static const String failed = '❌';
  static const String flaky = '⚠️';
  // The 'synthetic' icon is currently not used but is something to consider in
  // order to draw a distinction between user tests and test-like supporting
  // infrastructure.
  // static const String synthetic = '⏺';
  static const String success = '🎉';

  static String startGroup(String title) =>
      '::group::${title.replaceAll('\n', ' ')}';

  static final String endGroup = '::endgroup::';

  static String error(String message) => '::error::$message';

  static String warning(String message) => '::warning::$message';
}
