// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.reporter.compact;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../backend/live_test.dart';
import '../../backend/state.dart';
import '../../backend/suite.dart';
import '../../utils.dart';
import '../engine.dart';
import '../load_exception.dart';

/// The maximum console line length.
///
/// Lines longer than this will be cropped.
const _lineLength = 100;

/// A reporter that prints test results to the console in a single
/// continuously-updating line.
class CompactReporter {
  /// Whether the reporter should emit terminal color escapes.
  final bool _color;

  /// The terminal escape for green text, or the empty string if this is Windows
  /// or not outputting to a terminal.
  final String _green;

  /// The terminal escape for red text, or the empty string if this is Windows
  /// or not outputting to a terminal.
  final String _red;

  /// The terminal escape for yellow text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String _yellow;

  /// The terminal escape for removing test coloring, or the empty string if
  /// this is Windows or not outputting to a terminal.
  final String _noColor;

  /// Whether to use verbose stack traces.
  final bool _verboseTrace;

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

  /// The set of tests that have completed and been marked as skipped.
  final _skipped = new Set<LiveTest>();

  /// The set of tests that have completed and been marked as failing or error.
  final _failed = new Set<LiveTest>();

  /// The set of tests that are still running.
  final _active = new List<LiveTest>();

  /// Whether [close] has been called.
  bool _closed = false;

  /// The size of [_passed] last time a progress notification was printed.
  int _lastProgressPassed;

  /// The size of [_skipped] last time a progress notification was printed.
  int _lastProgressSkipped;

  /// The size of [_failed] last time a progress notification was printed.
  int _lastProgressFailed;

  /// The message printed for the last progress notification.
  String _lastProgressMessage;

  // Whether a newline has been printed since the last progress line.
  var _printedNewline = true;

  /// Creates a [ConsoleReporter] that will run all tests in [suites].
  ///
  /// [concurrency] controls how many suites are run at once. If [color] is
  /// `true`, this will use terminal colors; if it's `false`, it won't. If
  /// [verboseTrace] is `true`, this will print core library frames.
  CompactReporter(Iterable<Suite> suites, {int concurrency, bool color: true,
          bool verboseTrace: false})
      : _multiplePaths = suites.map((suite) => suite.path).toSet().length > 1,
        _multiplePlatforms =
            suites.map((suite) => suite.platform).toSet().length > 1,
        _engine = new Engine(suites, concurrency: concurrency),
        _verboseTrace = verboseTrace,
        _color = color,
        _green = color ? '\u001b[32m' : '',
        _red = color ? '\u001b[31m' : '',
        _yellow = color ? '\u001b[33m' : '',
        _noColor = color ? '\u001b[0m' : '' {
    _engine.onTestStarted.listen((liveTest) {
      if (_active.isEmpty) _progressLine(_description(liveTest));
      _active.add(liveTest);
      _printedNewline = false;

      liveTest.onStateChange.listen((state) {
        if (state.status != Status.complete) return;
        _active.remove(liveTest);

        if (state.result != Result.success) {
          _passed.remove(liveTest);
          _failed.add(liveTest);
        } else if (liveTest.test.metadata.skip) {
          _skipped.add(liveTest);
        } else {
          _passed.add(liveTest);
        }

        if (liveTest.test.metadata.skip &&
            liveTest.test.metadata.skipReason != null) {
          _progressLine(_description(liveTest));
          print('');
          print(indent('${_yellow}Skip: ${liveTest.test.metadata.skipReason}'
              '$_noColor'));
        } else {
          // Always display the name of the oldest active test, unless testing
          // is finished in which case display the last test to complete.
          if (_active.isEmpty) {
            _progressLine(_description(liveTest));
          } else {
            _progressLine(_description(_active.first));
          }

          _printedNewline = false;
        }
      });

      liveTest.onError.listen((error) {
        if (liveTest.state.status != Status.complete) return;

        _progressLine(_description(liveTest));
        if (!_printedNewline) print('');
        _printedNewline = true;

        if (error.error is! LoadException) {
          print(indent(error.error.toString()));
          var chain = terseChain(error.stackTrace, verbose: _verboseTrace);
          print(indent(chain.toString()));
          return;
        }

        print(indent(error.error.toString(color: _color)));

        // Only print stack traces for load errors that come from the user's code.
        if (error.error.innerError is! IOException &&
            error.error.innerError is! IsolateSpawnException &&
            error.error.innerError is! FormatException &&
            error.error.innerError is! String) {
          print(indent(terseChain(error.stackTrace).toString()));
        }
      });

      liveTest.onPrint.listen((line) {
        _progressLine(_description(liveTest));
        if (!_printedNewline) print('');
        _printedNewline = true;

        print(line);
      });
    });
  }

  /// Runs all tests in all provided suites.
  ///
  /// This returns `true` if all tests succeed, and `false` otherwise. It will
  /// only return once all tests have finished running.
  Future<bool> run() async {
    if (_stopwatch.isRunning) {
      throw new StateError("CompactReporter.run() may not be called more than "
          "once.");
    }

    if (_engine.liveTests.isEmpty) {
      print("No tests ran.");
      return true;
    }

    _stopwatch.start();
    var success = await _engine.run();
    if (_closed) return false;

    if (!success) {
      _progressLine('Some tests failed.', color: _red);
      print('');
    } else if (_passed.isEmpty) {
      _progressLine("All tests skipped.");
      print('');
    } else {
      _progressLine("All tests passed!");
      print('');
    }

    return success;
  }

  /// Signals that the caller is done with any test output and the reporter
  /// should release any resources it has allocated.
  Future close() {
    if (!_printedNewline) print("");
    _printedNewline = true;
    _closed = true;
    return _engine.close();
  }

  /// Prints a line representing the current state of the tests.
  ///
  /// [message] goes after the progress report, and may be truncated to fit the
  /// entire line within [_lineLength]. If [color] is passed, it's used as the
  /// color for [message].
  bool _progressLine(String message, {String color}) {
    // Print nothing if nothing has changed since the last progress line.
    if (_passed.length == _lastProgressPassed &&
        _skipped.length == _lastProgressSkipped &&
        _failed.length == _lastProgressFailed &&
        message == _lastProgressMessage) {
      return false;
    }

    _lastProgressPassed = _passed.length;
    _lastProgressSkipped = _skipped.length;
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

    if (_skipped.isNotEmpty) {
      buffer.write(_yellow);
      buffer.write(' ~');
      buffer.write(_skipped.length);
      buffer.write(_noColor);
    }

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
