// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/message.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/state.dart'; // ignore: implementation_imports

import '../../util/pretty_print.dart';
import '../engine.dart';
import '../load_exception.dart';
import '../load_suite.dart';
import '../reporter.dart';
import 'failure_summary.dart';
import 'reporter_mixin.dart';

/// A reporter that prints each test on its own line.
///
/// This is currently used in place of [CompactReporter] by `lib/test.dart`,
/// which can't transitively import `dart:io` but still needs access to a runner
/// so that test files can be run directly. This means that until issue 6943 is
/// fixed, this must not import `dart:io`.
class ExpandedReporter with ReporterMixin implements Reporter {
  /// Whether the reporter should emit terminal color escapes.
  final bool _color;

  /// The terminal escape for green text, or the empty string if this is Windows
  /// or not outputting to a terminal.
  final String green;

  /// The terminal escape for red text, or the empty string if this is Windows
  /// or not outputting to a terminal.
  final String red;

  /// The terminal escape for yellow text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String yellow;

  /// The terminal escape for gray text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String gray;

  /// The terminal escape for bold text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String bold;

  /// The terminal escape for removing test coloring, or the empty string if
  /// this is Windows or not outputting to a terminal.
  final String noColor;

  /// The engine used to run the tests.
  final Engine engine;

  /// Whether the path to each test's suite should be printed.
  final bool printPath;

  /// Whether the platform each test is running on should be printed.
  final bool printPlatform;

  /// A stopwatch that tracks the duration of the full run.
  final _stopwatch = Stopwatch();

  /// The size of `engine.passed` last time a progress notification was
  /// printed.
  int _lastProgressPassed = 0;

  /// The size of `engine.skipped` last time a progress notification was
  /// printed.
  int _lastProgressSkipped = 0;

  /// The size of `engine.failed` last time a progress notification was
  /// printed.
  int _lastProgressFailed = 0;

  /// The message printed for the last progress notification.
  String _lastProgressMessage = '';

  /// The suffix added to the last progress notification.
  String? _lastProgressSuffix;

  /// Whether the reporter is paused.
  var _paused = false;

  // Whether a notice should be logged about enabling stack trace chaining at
  // the end of all tests running.
  var _shouldPrintStackTraceChainingNotice = false;

  /// The set of all subscriptions to various streams.
  final _subscriptions = <StreamSubscription>{};

  final StringSink sink;

  /// Watches the tests run by [engine] and prints their results to the
  /// terminal.
  ///
  /// If [color] is `true`, this will use terminal colors; if it's `false`, it
  /// won't. If [printPath] is `true`, this will print the path name as part of
  /// the test description. Likewise, if [printPlatform] is `true`, this will
  /// print the platform as part of the test description.
  static ExpandedReporter watch(
    Engine engine,
    StringSink sink, {
    required bool color,
    required bool printPath,
    required bool printPlatform,
  }) => ExpandedReporter._(
    engine,
    sink,
    color: color,
    printPath: printPath,
    printPlatform: printPlatform,
  );

  ExpandedReporter._(
    this.engine,
    this.sink, {
    required bool color,
    required bool printPath,
    required bool printPlatform,
  }) : printPath = printPath,
       printPlatform = printPlatform,
       _color = color,
       green = color ? '\u001b[32m' : '',
       red = color ? '\u001b[31m' : '',
       yellow = color ? '\u001b[33m' : '',
       gray = color ? '\u001b[90m' : '',
       bold = color ? '\u001b[1m' : '',
       noColor = color ? '\u001b[0m' : '' {
    _subscriptions.add(engine.onTestStarted.listen(_onTestStarted));

    // Convert the future to a stream so that the subscription can be paused or
    // canceled.
    _subscriptions.add(engine.success.asStream().listen(_onDone));
  }

  @override
  void pause() {
    if (_paused) return;
    _paused = true;

    _stopwatch.stop();

    for (var subscription in _subscriptions) {
      subscription.pause();
    }
  }

  @override
  void resume() {
    if (!_paused) return;

    _stopwatch.start();

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
    if (liveTest.suite is! LoadSuite) {
      if (!_stopwatch.isRunning) _stopwatch.start();

      // If this is the first non-load test to start, print a progress line so
      // the user knows what's running.
      if (engine.active.length == 1) _progressLine(formatDescription(liveTest));

      // The engine surfaces load tests when there are no other tests running,
      // but because the expanded reporter's output is always visible, we don't
      // emit information about them unless they fail.
      _subscriptions.add(
        liveTest.onStateChange.listen(
          (state) => _onStateChange(liveTest, state),
        ),
      );
    } else if (engine.active.isEmpty &&
        engine.activeSuiteLoads.length == 1 &&
        engine.activeSuiteLoads.first == liveTest &&
        liveTest.test.name.startsWith('loading ')) {
      // Print a progress line for ongoing suite loading synthetic test since it
      // may be slow (or stuck) depending on the platform.
      _progressLine(formatDescription(liveTest));
    }

    _subscriptions.add(
      liveTest.onError.listen(
        (error) => _onError(liveTest, error.error, error.stackTrace),
      ),
    );

    _subscriptions.add(
      liveTest.onMessage.listen((message) {
        _progressLine(formatDescription(liveTest));
        var text = message.text;
        if (message.type == MessageType.skip) text = '  $yellow$text$noColor';
        sink.writeln(text);
      }),
    );
  }

  /// A callback called when [liveTest]'s state becomes [state].
  void _onStateChange(LiveTest liveTest, State state) {
    if (state.status != Status.complete) return;

    // If any tests are running, display the name of the oldest active
    // test.
    if (engine.active.isNotEmpty) {
      _progressLine(formatDescription(engine.active.first));
    }
  }

  /// A callback called when [liveTest] throws [error].
  void _onError(LiveTest liveTest, Object error, StackTrace stackTrace) {
    if (!liveTest.test.metadata.chainStackTraces &&
        !liveTest.suite.isLoadSuite) {
      _shouldPrintStackTraceChainingNotice = true;
    }

    if (liveTest.state.status != Status.complete) return;

    _progressLine(formatDescription(liveTest), suffix: ' $bold$red[E]$noColor');

    if (error is! LoadException) {
      sink
        ..writeln(indent('$error'))
        ..writeln(indent('$stackTrace'));
      return;
    }

    // TODO - what type is this?
    sink.writeln(indent(error.toString(color: _color)));

    // Only print stack traces for load errors that come from the user's code.
    if (error.innerError is! FormatException && error.innerError is! String) {
      sink.writeln(indent('$stackTrace'));
    }
  }

  /// A callback called when the engine is finished running tests.
  ///
  /// [success] will be `true` if all tests passed, `false` if some tests
  /// failed, and `null` if the engine was closed prematurely.
  void _onDone(bool? success) {
    _cancel();
    // A null success value indicates that the engine was closed before the
    // tests finished running, probably because of a signal from the user, in
    // which case we shouldn't print summary information.
    if (success == null) return;

    if (engine.liveTests.isEmpty) {
      sink.writeln('No tests ran.');
    } else if (!success) {
      for (var liveTest in engine.active) {
        _progressLine(
          formatDescription(liveTest),
          suffix: ' - did not complete $bold$red[E]$noColor',
        );
      }
      _progressLine('Some tests failed.', color: red);

      writeFailureSummary(
        sink,
        failed: engine.failed,
        active: engine.active,
        red: red,
        noColor: noColor,
      );
    } else if (engine.passed.isEmpty) {
      _progressLine('All tests skipped.');
    } else {
      _progressLine('All tests passed!');
    }

    if (_shouldPrintStackTraceChainingNotice) {
      sink
        ..writeln('')
        ..writeln(
          'Consider enabling the flag chain-stack-traces to '
          'receive more detailed exceptions.\n'
          "For example, 'dart test --chain-stack-traces'.",
        );
    }
  }

  /// Prints a line representing the current state of the tests.
  ///
  /// [message] goes after the progress report. If [color] is passed, it's used
  /// as the color for [message]. If [suffix] is passed, it's added to the end
  /// of [message].
  void _progressLine(String message, {String? color, String? suffix}) {
    // Print nothing if nothing has changed since the last progress line.
    if (engine.passed.length == _lastProgressPassed &&
        engine.skipped.length == _lastProgressSkipped &&
        engine.failed.length == _lastProgressFailed &&
        message == _lastProgressMessage &&
        // Don't re-print just because a suffix was removed.
        (suffix == null || suffix == _lastProgressSuffix)) {
      return;
    }

    _lastProgressPassed = engine.passed.length;
    _lastProgressSkipped = engine.skipped.length;
    _lastProgressFailed = engine.failed.length;
    _lastProgressMessage = message;
    _lastProgressSuffix = suffix;

    if (suffix != null) message += suffix;
    color ??= '';
    var duration = _stopwatch.elapsed;
    var buffer = StringBuffer();

    // \r moves back to the beginning of the current line.
    buffer.write('${_timeString(duration)} ');
    buffer.write(green);
    buffer.write('+');
    buffer.write(engine.passed.length);
    buffer.write(noColor);

    if (engine.skipped.isNotEmpty) {
      buffer.write(yellow);
      buffer.write(' ~');
      buffer.write(engine.skipped.length);
      buffer.write(noColor);
    }

    if (engine.failed.isNotEmpty) {
      buffer.write(red);
      buffer.write(' -');
      buffer.write(engine.failed.length);
      buffer.write(noColor);
    }

    buffer.write(': ');
    buffer.write(color);
    buffer.write(message);
    buffer.write(noColor);

    sink.writeln(buffer.toString());
  }

  /// Returns a representation of [duration] as `MM:SS`.
  String _timeString(Duration duration) {
    return "${duration.inMinutes.toString().padLeft(2, '0')}:"
        "${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  /// Returns a description of [liveTest].
  ///
  /// This differs from the test's own description in that it may also include
  /// the suite's name.
}
