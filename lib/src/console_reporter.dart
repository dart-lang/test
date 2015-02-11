// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.console_reporter;

import 'dart:async';
import 'dart:io';

import 'engine.dart';
import 'io.dart';
import 'live_test.dart';
import 'state.dart';
import 'suite.dart';
import 'utils.dart';

/// The terminal escape for green text, or the empty string if this is Windows
/// or not outputting to a terminal.
final _green = getSpecial('\u001b[32m');

/// The terminal escape for red text, or the empty string if this is Windows or
/// not outputting to a terminal.
final _red = getSpecial('\u001b[31m');

/// The terminal escape for removing test coloring, or the empty string if this
/// is Windows or not outputting to a terminal.
final _noColor = getSpecial('\u001b[0m');

/// The maximum console line length.
///
/// Lines longer than this will be cropped.
const _lineLength = 80;

/// A reporter that prints test results to the console in a single
/// continuously-updating line.
class ConsoleReporter {
  /// The engine used to run the tests.
  final Engine _engine;

  /// Whether multiple test suites are being run.
  final bool _multipleSuites;

  /// A stopwatch that tracks the duration of the full run.
  final _stopwatch = new Stopwatch();

  /// The set of tests that have completed and been marked as passing.
  final _passed = new Set<LiveTest>();

  /// The set of tests that have completed and been marked as failing or error.
  final _failed = new Set<LiveTest>();

  /// Creates a [ConsoleReporter] that will run all tests in [suites].
  ConsoleReporter(Iterable<Suite> suites)
      : _multipleSuites = suites.length > 1,
        _engine = new Engine(suites) {

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
      });

      liveTest.onError.listen((error) {
        if (liveTest.state.status != Status.complete) return;

        // TODO(nweiz): don't re-print the progress line if a test has multiple
        // errors in a row.
        _progressLine(_description(liveTest));
        print('');
        print(indent("${error.error}\n${error.stackTrace}"));
      });
    });
  }

  /// Runs all tests in all provided suites.
  ///
  /// This returns `true` if all tests succeed, and `false` otherwise. It will
  /// only return once all tests have finished running.
  Future<bool> run() {
    if (_stopwatch.isRunning) {
      throw new StateError("ConsoleReporter.run() may not be called more than "
          "once.");
    }

    _stopwatch.start();
    return _engine.run().then((success) {
      if (_engine.liveTests.isEmpty) {
        print("\nNo tests ran.");
      } else if (success) {
        _progressLine("All tests passed!");
        print('');
      } else {
        _progressLine('Some tests failed.', color: _red);
        print('');
      }

      return success;
    });
  }

  /// Prints a line representing the current state of the tests.
  ///
  /// [message] goes after the progress report, and may be truncated to fit the
  /// entire line within [_lineLength]. If [color] is passed, it's used as the
  /// color for [message].
  void _progressLine(String message, {String color}) {
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
    buffer.write(_truncate(message, _lineLength - length));
    buffer.write(_noColor);

    // Pad the rest of the line so that it looks erased.
    length = buffer.length - nonVisible - _noColor.length;
    buffer.write(' ' * (_lineLength - length));
    stdout.write(buffer.toString());
  }

  /// Returns a representation of [duration] as `MM:SS`.
  String _timeString(Duration duration) {
    return "${duration.inMinutes.toString().padLeft(2, '0')}:"
        "${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  /// Truncates [text] to fit within [maxLength].
  ///
  /// This will try to truncate along word boundaries and preserve words both at
  /// the beginning and the end of [text].
  String _truncate(String text, int maxLength) {
    // Return the full message if it fits.
    if (text.length <= maxLength) return text;

    // If we can fit the first and last three words, do so.
    var words = text.split(' ');
    if (words.length > 1) {
      var i = words.length;
      var length = words.first.length + 4;
      do {
        i--;
        length += 1 + words[i].length;
      } while (length <= maxLength && i > 0);
      if (length > maxLength || i == 0) i++;
      if (i < words.length - 4) {
        // Require at least 3 words at the end.
        var buffer = new StringBuffer();
        buffer.write(words.first);
        buffer.write(' ...');
        for ( ; i < words.length; i++) {
          buffer.write(' ');
          buffer.write(words[i]);
        }
        return buffer.toString();
      }
    }

    // Otherwise truncate to return the trailing text, but attempt to start at
    // the beginning of a word.
    var result = text.substring(text.length - maxLength + 4);
    var firstSpace = result.indexOf(' ');
    if (firstSpace > 0) {
      result = result.substring(firstSpace);
    }
    return '...$result';
  }

  /// Returns a description of [liveTest].
  ///
  /// This differs from the test's own description in that it may also include
  /// the suite's name.
  String _description(LiveTest liveTest) {
    if (_multipleSuites) return "${liveTest.suite.name}: ${liveTest.test.name}";
    return liveTest.test.name;
  }
}
