// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:test_api/src/backend/live_test.dart';
import 'package:test_api/src/backend/message.dart';
import 'package:test_api/src/backend/state.dart';
import 'package:test_api/src/backend/util/pretty_print.dart';

import '../engine.dart';
import '../load_suite.dart';
import '../reporter.dart';
import 'reporter_mixin.dart';

/// A reporter that prints test output using formatting for Github Actions.
///
/// See
/// https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
/// for a description of the output format, and
/// https://github.com/dart-lang/test/issues/1415 for discussions about this
/// implementation.
class GithubReporter with ReporterMixin implements Reporter {
  /// The engine used to run the tests.
  final Engine _engine;

  /// Whether the path to each test's suite should be printed.
  @override
  final bool printPath;

  /// Whether the platform each test is running on should be printed.
  @override
  final bool printPlatform;

  /// Whether the reporter is paused.
  var _paused = false;

  final StringSink _sink;

  final Map<LiveTest, List<Message>> _testMessages = {};

  final Set<LiveTest> _completedTests = {};

  /// The github markdown `::group::` that is currently open.
  var _activeGroup = _ReportGroup.ungrouped;

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
    this.printPath,
    this.printPlatform,
  ) {
    subscriptions.add(_engine.onTestStarted.listen(_onTestStarted));
    subscriptions.add(_engine.success.asStream().listen(_onDone));

    // Add a spacer between pre-test output and the test results.
    _sink.writeln();
  }

  @override
  void pause() {
    if (_paused) return;
    _paused = true;

    for (var subscription in subscriptions) {
      subscription.pause();
    }
  }

  @override
  void resume() {
    if (!_paused) return;
    _paused = false;

    for (var subscription in subscriptions) {
      subscription.resume();
    }
  }

  /// A callback called when the engine begins running [liveTest].
  void _onTestStarted(LiveTest liveTest) {
    // Convert the future to a stream so that the subscription can be paused or
    // canceled.
    subscriptions.add(
      liveTest.onComplete.asStream().listen((_) => _onComplete(liveTest)),
    );

    subscriptions.add(
      liveTest.onError.listen(
        (error) => _onError(liveTest, error.error, error.stackTrace),
      ),
    );

    // Collect messages from tests as they are emitted.
    subscriptions.add(
      liveTest.onMessage.listen((message) {
        if (_completedTests.contains(liveTest)) {
          // The test has already completed and it's previous messages were
          // written out; ensure this post-completion output is not lost.
          if (!_activeGroup.isUngrouped) {
            _sink.writeln(_GithubMarkup.endGroup);
            _activeGroup = _ReportGroup.ungrouped;
          }
          _sink.writeln(message.text);
        } else {
          _testMessages.putIfAbsent(liveTest, () => []).add(message);
        }
      }),
    );
  }

  /// A callback called when [liveTest] finishes running.
  void _onComplete(LiveTest test) {
    final errors = test.errors;
    final messages = _testMessages[test] ?? [];
    final skipped = test.state.result == Result.skipped;
    final failed = errors.isNotEmpty;
    final loadSuite = test.suite is LoadSuite;
    final synthetic =
        loadSuite ||
        test.individualName == '(setUpAll)' ||
        test.individualName == '(tearDownAll)';

    // Mark this test as having completed.
    _completedTests.add(test);

    // Don't emit any info for loadSuite, setUpAll, or tearDownAll tests
    // unless they contain errors or other info.
    if (synthetic && (errors.isEmpty && messages.isEmpty)) {
      return;
    }

    // For now, we use the same icon for both tests and test-like structures
    // (loadSuite, setUpAll, tearDownAll).
    var defaultIcon = synthetic ? _GithubMarkup.passed : _GithubMarkup.passed;
    final prefix = failed
        ? _GithubMarkup.failed
        : skipped
        ? _GithubMarkup.skipped
        : defaultIcon;
    final statusSuffix = failed
        ? ' (failed)'
        : skipped
        ? ' (skipped)'
        : '';

    var name = test.test.name;
    if (!loadSuite) {
      if (printPath && test.suite.path != null) {
        name = '${test.suite.path}: $name';
      }
    }
    if (printPlatform) {
      name =
          '[${test.suite.platform.runtime.name}, '
          '${test.suite.platform.compiler.name}] $name';
    }
    if (skipped) {
      if (_activeGroup.isPassing) {
        _sink.writeln(_GithubMarkup.endGroup);
      }
      if (!_activeGroup.isSkipped) {
        _sink.writeln(_GithubMarkup.startGroup('⏭️ Skipped tests'));
        _activeGroup = _ReportGroup.skipped;
      }
      _sink.writeln('$prefix $name$statusSuffix');
      for (var message in messages) {
        _sink.writeln(message.text);
      }
    } else if (errors.isEmpty) {
      if (_activeGroup.isSkipped) {
        _sink.writeln(_GithubMarkup.endGroup);
      }
      if (!_activeGroup.isPassing) {
        _sink.writeln(_GithubMarkup.startGroup('✅ Passing tests'));
        _activeGroup = _ReportGroup.passing;
      }
      _sink.writeln('$prefix $name$statusSuffix');
      for (var message in messages) {
        _sink.writeln(message.text);
      }
    } else {
      if (!_activeGroup.isUngrouped) {
        _sink.writeln(_GithubMarkup.endGroup);
        _activeGroup = _ReportGroup.ungrouped;
      }
      _sink.writeln(_GithubMarkup.startGroup('$prefix $name$statusSuffix'));
      for (var message in messages) {
        _sink.writeln(message.text);
      }
      for (var error in errors) {
        _sink.writeln('${error.error}');
        _sink.writeln(error.stackTrace.toString().trimRight());
      }
      _sink.writeln(_GithubMarkup.endGroup);
    }
  }

  /// A callback called when [test] throws [error].
  void _onError(LiveTest test, Object error, StackTrace stackTrace) {
    if (_completedTests.contains(test)) {
      final loadSuite = test.suite is LoadSuite;

      final prefix = _GithubMarkup.failed;
      final statusSuffix = ' (failed after test completion)';

      var name = test.test.name;
      if (!loadSuite) {
        if (printPath && test.suite.path != null) {
          name = '${test.suite.path}: $name';
        }
      }
      if (printPlatform) {
        name =
            '[${test.suite.platform.runtime.name}, '
            '${test.suite.platform.compiler.name}] $name';
      }

      if (!_activeGroup.isUngrouped) {
        _sink.writeln(_GithubMarkup.endGroup);
        _activeGroup = _ReportGroup.ungrouped;
      }
      _sink.writeln(_GithubMarkup.startGroup('$prefix $name$statusSuffix'));
      _sink.writeln('$error');
      _sink.writeln(stackTrace.toString().trimRight());
      _sink.writeln(_GithubMarkup.endGroup);
    }
  }

  void _onDone(bool? success) {
    cancelSubscriptions();

    if (!_activeGroup.isUngrouped) {
      _sink.writeln(_GithubMarkup.endGroup);
      _activeGroup = _ReportGroup.ungrouped;
    }

    _sink.writeln();

    final hadFailures = _engine.failed.isNotEmpty;
    final message = StringBuffer(
      '${_engine.passed.length} '
      '${pluralize('test', _engine.passed.length)} passed',
    );
    if (_engine.failed.isNotEmpty) {
      message.write(', ${_engine.failed.length} failed');
    }
    if (_engine.skipped.isNotEmpty) {
      message.write(', ${_engine.skipped.length} skipped');
    }
    message.write('.');
    _sink.writeln(
      hadFailures
          ? _GithubMarkup.error(message.toString())
          : '${_GithubMarkup.success} $message',
    );
  }
}

abstract class _GithubMarkup {
  // Char sets avilable at https://www.compart.com/en/unicode/.
  static const String passed = '✅';
  static const String skipped = '⏭️';
  static const String failed = '❌';
  // The 'synthetic' icon is currently not used but is something to consider in
  // order to draw a distinction between user tests and test-like supporting
  // infrastructure.
  // static const String synthetic = '⏺';
  static const String success = '🎉';

  static String startGroup(String title) =>
      '::group::${title.replaceAll('\n', ' ')}';

  static final String endGroup = '::endgroup::';

  static String error(String message) => '::error::$message';
}

enum _ReportGroup {
  passing,
  skipped,
  ungrouped;

  bool get isPassing => this == _ReportGroup.passing;
  bool get isSkipped => this == _ReportGroup.skipped;
  bool get isUngrouped => this == _ReportGroup.ungrouped;
}
