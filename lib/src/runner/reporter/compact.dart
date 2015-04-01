// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.reporter.compact;

import 'dart:async';
import 'dart:io';

import '../../backend/live_test.dart';
import '../../backend/state.dart';
import '../../backend/suite.dart';
import '../../utils.dart';
import '../engine.dart';

/// The maximum console line length.
///
/// Lines longer than this will be cropped.
const _lineLength = 100;

/// A reporter that prints test results to the console in a single
/// continuously-updating line.
class CompactReporter {
  /// The terminal escape for green text, or the empty string if this is Windows
  /// or not outputting to a terminal.
  final String _green;

  /// The terminal escape for red text, or the empty string if this is Windows
  /// or not outputting to a terminal.
  final String _red;

  /// The terminal escape for removing test coloring, or the empty string if
  /// this is Windows or not outputting to a terminal.
  final String _noColor;

  /// The engine used to run the tests.
  final Engine _engine;

  /// Whether multiple test files are being run.
  final bool _multiplePaths;

  /// Whether tests are being run on multiple platforms.
  final bool _multiplePlatforms;

  /// A stopwatch that tracks the duration of the full run.
  final _stopwatch = new Stopwatch();

  /// The set of tests that have completed and been marked as passing.
  final _passed = new Set<LiveTest>();

  /// The set of tests that have completed and been marked as failing or error.
  final _failed = new Set<LiveTest>();

  /// The size of [_passed] last time a progress notification was printed.
  int _lastProgressPassed;

  /// The size of [_failed] last time a progress notification was printed.
  int _lastProgressFailed;

  /// The message printed for the last progress notification.
  String _lastProgressMessage;

  /// Creates a [ConsoleReporter] that will run all tests in [suites].
  ///
  /// If [color] is `true`, this will use terminal colors; if it's `false`, it
  /// won't.
  CompactReporter(Iterable<Suite> suites, {bool color: true})
      : _multiplePaths = suites.map((suite) => suite.path).toSet().length > 1,
        _multiplePlatforms =
            suites.map((suite) => suite.platform).toSet().length > 1,
        _engine = new Engine(suites),
        _green = color ? '\u001b[32m' : '',
        _red = color ? '\u001b[31m' : '',
        _noColor = color ? '\u001b[0m' : '' {
    // Whether a newline has been printed since the last progress line.
    var printedNewline = false;
    _engine.onTestStarted.listen((liveTest) {
      _progressLine(_description(liveTest));
      liveTest.onStateChange.listen((state) {
        if (state.status != Status.complete) return;
        if (state.result == Result.success) {
          _passed.add(liveTest);
        } else {
          _passed.remove(liveTest);
          _failed.add(liveTest);
        }
        _progressLine(_description(liveTest));
        printedNewline = false;
      });

      liveTest.onError.listen((error) {
        if (liveTest.state.status != Status.complete) return;

        _progressLine(_description(liveTest));
        if (!printedNewline) print('');
        printedNewline = true;

        print(indent(error.error.toString()));
        print(indent(terseChain(error.stackTrace).toString()));
      });

      liveTest.onPrint.listen((line) {
        _progressLine(_description(liveTest));
        if (!printedNewline) print('');
        printedNewline = true;

        print(line);
      });
    });
  }

  /// Runs all tests in all provided suites.
  ///
  /// This returns `true` if all tests succeed, and `false` otherwise. It will
  /// only return once all tests have finished running.
  Future<bool> run() {
    if (_stopwatch.isRunning) {
      throw new StateError("CompactReporter.run() may not be called more than "
          "once.");
    }

    if (_engine.liveTests.isEmpty) {
      print("No tests ran.");
      return new Future.value(true);
    }

    _stopwatch.start();
    return _engine.run().then((success) {
      if (success) {
        _progressLine("All tests passed!");
        print('');
      } else {
        _progressLine('Some tests failed.', color: _red);
        print('');
      }

      return success;
    });
  }

  /// Signals that the caller is done with any test output and the reporter
  /// should release any resources it has allocated.
  Future close() => _engine.close();

  /// Prints a line representing the current state of the tests.
  ///
  /// [message] goes after the progress report, and may be truncated to fit the
  /// entire line within [_lineLength]. If [color] is passed, it's used as the
  /// color for [message].
  bool _progressLine(String message, {String color}) {
    // Print nothing if nothing has changed since the last progress line.
    if (_passed.length == _lastProgressPassed &&
        _failed.length == _lastProgressFailed &&
        message == _lastProgressMessage) {
      return false;
    }

    _lastProgressPassed = _passed.length;
    _lastProgressFailed = _failed.length;
    _lastProgressMessage = message;

    if (color == null) color = '';
    var duration = _stopwatch.elapsed;
    var buffer = new StringBuffer();

    // \r moves back to the beginning of the current line.
    buffer.write('\r${_timeString(duration)} ');
    buffer.write(_green);
    buffer.write('+');
    buffer.write(_passed.length);
    buffer.write(_noColor);

    if (_failed.isNotEmpty) {
      buffer.write(_red);
      buffer.write(' -');
      buffer.write(_failed.length);
      buffer.write(_noColor);
    }

    buffer.write(': ');
    buffer.write(color);

    // Ensure the line fits within [_lineLength]. [buffer] includes the color
    // escape sequences too. Because these sequences are not visible characters,
    // we make sure they are not counted towards the limit.
    var nonVisible = 1 + _green.length + _noColor.length + color.length +
        (_failed.isEmpty ? 0 : _red.length + _noColor.length);
    var length = buffer.length - nonVisible;
    buffer.write(truncate(message, _lineLength - length));
    buffer.write(_noColor);

    // Pad the rest of the line so that it looks erased.
    length = buffer.length - nonVisible - _noColor.length;
    buffer.write(' ' * (_lineLength - length));
    stdout.write(buffer.toString());
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
  String _description(LiveTest liveTest) {
    var name = liveTest.test.name;

    if (_multiplePaths && liveTest.suite.path != null) {
      name = "${liveTest.suite.path}: $name";
    }

    if (_multiplePlatforms && liveTest.suite.platform != null) {
      name = "[${liveTest.suite.platform}] $name";
    }

    return name;
  }
}
