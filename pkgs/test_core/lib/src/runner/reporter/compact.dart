// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/state.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/util/pretty_print.dart'; // ignore: implementation_imports

import '../../util/io.dart';
import '../../util/pretty_print.dart';
import '../../util/pretty_print.dart' as utils;
import '../engine.dart';
import '../load_exception.dart';
import '../load_suite.dart';
import '../reporter.dart';
import 'reporter_mixin.dart';

/// A reporter that prints test results to the console in a single
/// continuously-updating line.
class CompactReporter with ReporterMixin implements Reporter {
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

  /// The terminal escape code for cyan text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String cyan;

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

  /// Whether we've started [_stopwatch].
  ///
  /// We can't just use `_stopwatch.isRunning` because the stopwatch is stopped
  /// when the reporter is paused.
  var _stopwatchStarted = false;

  /// The size of `engine.passed` last time a progress notification was
  /// printed.
  int _lastProgressPassed = 0;

  /// The size of `engine.skipped` last time a progress notification was
  /// printed.
  int? _lastProgressSkipped;

  /// The size of `engine.failed` last time a progress notification was
  /// printed.
  int? _lastProgressFailed;

  /// The duration of the test run in seconds last time a progress notification
  /// was printed.
  int? _lastProgressElapsed;

  /// The message printed for the last progress notification.
  String? _lastProgressMessage;

  /// The suffix added to the last progress notification.
  String? _lastProgressSuffix;

  /// Whether the message printed for the last progress notification was
  /// truncated.
  bool? _lastProgressTruncated;

  // Whether a newline has been printed since the last progress line.
  var _printedNewline = true;

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
  static CompactReporter watch(
    Engine engine,
    StringSink sink, {
    required bool color,
    required bool printPath,
    required bool printPlatform,
  }) => CompactReporter._(
    engine,
    sink,
    color: color,
    printPath: printPath,
    printPlatform: printPlatform,
  );

  CompactReporter._(
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
       cyan = color ? '\u001b[36m' : '',
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

    if (!_printedNewline) sink.writeln('');
    _printedNewline = true;
    _stopwatch.stop();

    // Force the next message to be printed, even if it's identical to the
    // previous one. If the reporter was paused, text was probably printed
    // during the pause.
    _lastProgressMessage = null;

    for (var subscription in _subscriptions) {
      subscription.pause();
    }
  }

  @override
  void resume() {
    if (!_paused) return;
    _paused = false;

    if (_stopwatchStarted) _stopwatch.start();

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
    if (!_stopwatchStarted) {
      _stopwatchStarted = true;
      _stopwatch.start();

      // Keep updating the time even when nothing else is happening.
      _subscriptions.add(
        Stream<void>.periodic(
          const Duration(seconds: 1),
        ).listen((_) => _progressLine(_lastProgressMessage ?? '')),
      );
    }

    // If this is the first test or suite load to start, print a progress line
    // so the user knows what's running.
    if ((engine.active.length == 1 && engine.active.first == liveTest) ||
        (engine.active.isEmpty &&
            engine.activeSuiteLoads.length == 1 &&
            engine.activeSuiteLoads.first == liveTest)) {
      _progressLine(formatDescription(liveTest));
    }

    _subscriptions.add(
      liveTest.onStateChange.listen((state) => _onStateChange(liveTest, state)),
    );

    _subscriptions.add(
      liveTest.onError.listen(
        (error) => _onError(liveTest, error.error, error.stackTrace),
      ),
    );

    _subscriptions.add(
      liveTest.onMessage.listen((message) {
        if (liveTest.test.metadata.skip) return;
        _progressLine(formatDescription(liveTest), truncate: false);
        if (!_printedNewline) sink.writeln('');
        _printedNewline = true;
        sink.writeln(message.text);
      }),
    );

    liveTest.onComplete.then((_) {
      var result = liveTest.state.result;
      if (result != Result.error && result != Result.failure) return;
      var quotedName = Platform.isWindows
          ? '"${liveTest.test.name.replaceAll('"', '"""')}"'
          : "'${liveTest.test.name.replaceAll("'", r"'\''")}'";
      sink.writeln('');
      sink.writeln(
        '$bold${cyan}To run this test again:$noColor '
        '${Platform.executable} test ${liveTest.suite.path} '
        '-p ${liveTest.suite.platform.runtime.identifier} '
        '--plain-name $quotedName',
      );
    });
  }

  /// A callback called when [liveTest]'s state becomes [state].
  void _onStateChange(LiveTest liveTest, State state) {
    if (state.status != Status.complete) return;

    // Errors are printed in [onError]; no need to print them here as well.
    if (state.result == Result.failure) return;
    if (state.result == Result.error) return;

    // Always display the name of the oldest active test, unless testing
    // is finished in which case display the last test to complete.
    if (engine.active.isEmpty) {
      _progressLine(formatDescription(liveTest));
    } else {
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

    _progressLine(
      formatDescription(liveTest),
      truncate: false,
      suffix: ' $bold$red[E]$noColor',
    );
    if (!_printedNewline) sink.writeln('');
    _printedNewline = true;

    if (error is! LoadException) {
      sink.writeln(indent(error.toString()));
      sink.writeln(indent('$stackTrace'));
      return;
    }

    // TODO - what type is this?
    sink.writeln(indent(error.toString(color: _color)));

    // Only print stack traces for load errors that come from the user's code.
    if (error.innerError is! IOException &&
        error.innerError is! IsolateSpawnException &&
        error.innerError is! FormatException &&
        error.innerError is! String) {
      sink.writeln(indent('$stackTrace'));
    }
  }

  /// A callback called when the engine is finished running tests.
  ///
  /// [success] will be `true` if all tests passed, `false` if some tests
  /// failed, and `null` if the engine was closed prematurely.
  void _onDone(bool? success) {
    _cancel();
    _stopwatch.stop();

    // A null success value indicates that the engine was closed before the
    // tests finished running, probably because of a signal from the user. We
    // shouldn't print summary information, we should just make sure the
    // terminal cursor is on its own line.
    if (success == null) {
      if (!_printedNewline) sink.writeln('');
      _printedNewline = true;
      return;
    }

    if (engine.liveTests.isEmpty) {
      if (!_printedNewline) sink.write('\r');
      var message = 'No tests ran.';
      sink.write(message);

      // Add extra padding to overwrite any load messages.
      if (!_printedNewline) sink.write(' ' * (lineLength - message.length));
      sink.writeln('');
    } else if (!success) {
      for (var liveTest in engine.active) {
        _progressLine(
          formatDescription(liveTest),
          truncate: false,
          suffix: ' - did not complete $bold$red[E]$noColor',
        );
        sink.writeln('');
      }
      _progressLine('Some tests failed.', color: red);
      sink.writeln('');
    } else if (engine.passed.isEmpty) {
      _progressLine('${yellow}All tests skipped.$noColor');
      sink.writeln('');
    } else if (engine.skipped.isEmpty) {
      _progressLine('All tests passed!');
      sink.writeln('');
    } else {
      final skippedCount = engine.skipped.length;
      _progressLine(
        '$yellow'
        '$skippedCount skipped ${pluralize('test', skippedCount)}.'
        '$noColor',
      );
      sink.writeln('');
      _progressLine('All other tests passed!');
      sink.writeln('');
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
  /// [message] goes after the progress report, and may be truncated to fit the
  /// entire line within [lineLength]. If [color] is passed, it's used as the
  /// color for [message]. If [suffix] is passed, it's added to the end of
  /// [message].
  bool _progressLine(
    String message, {
    String? color,
    bool truncate = true,
    String? suffix,
  }) {
    var elapsed = _stopwatch.elapsed.inSeconds;

    // Print nothing if nothing has changed since the last progress line.
    if (engine.passed.length == _lastProgressPassed &&
        engine.skipped.length == _lastProgressSkipped &&
        engine.failed.length == _lastProgressFailed &&
        message == _lastProgressMessage &&
        // Don't re-print just because a suffix was removed.
        (suffix == null || suffix == _lastProgressSuffix) &&
        // Don't re-print just because the message became re-truncated, because
        // that doesn't add information.
        (truncate || !_lastProgressTruncated!) &&
        // If we printed a newline, that means the last line *wasn't* a progress
        // line. In that case, we don't want to print a new progress line just
        // because the elapsed time changed.
        (_printedNewline || elapsed == _lastProgressElapsed)) {
      return false;
    }

    _lastProgressPassed = engine.passed.length;
    _lastProgressSkipped = engine.skipped.length;
    _lastProgressFailed = engine.failed.length;
    _lastProgressElapsed = elapsed;
    _lastProgressMessage = message;
    _lastProgressSuffix = suffix;
    _lastProgressTruncated = truncate;

    if (suffix != null) message += suffix;
    color ??= '';
    var duration = _stopwatch.elapsed;
    var buffer = StringBuffer();

    // \r moves back to the beginning of the current line.
    buffer.write('\r${_timeString(duration)} ');
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

    // Ensure the line fits within [lineLength]. [buffer] includes the color
    // escape sequences too. Because these sequences are not visible characters,
    // we make sure they are not counted towards the limit.
    var length = withoutColors(buffer.toString()).length;
    if (truncate) message = utils.truncate(message, lineLength - length);
    buffer.write(message);
    buffer.write(noColor);

    // Pad the rest of the line so that it looks erased.
    buffer.write(' ' * (lineLength - withoutColors(buffer.toString()).length));
    sink.write(buffer.toString());

    _printedNewline = false;
    return true;
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
