// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
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

/// A reporter that only prints when a test fails.
class FailuresOnlyReporter implements Reporter {
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

  /// The terminal escape for gray text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String _gray;

  /// The terminal escape for bold text, or the empty string if this is
  /// Windows or not outputting to a terminal.
  final String _bold;

  /// The terminal escape for removing test coloring, or the empty string if
  /// this is Windows or not outputting to a terminal.
  final String _noColor;

  /// The engine used to run the tests.
  final Engine _engine;

  /// Whether the path to each test's suite should be printed.
  final bool _printPath;

  /// Whether the platform each test is running on should be printed.
  final bool _printPlatform;

  /// The size of `_engine.passed` last time a progress notification was
  /// printed.
  int _lastProgressPassed = 0;

  /// The size of `_engine.skipped` last time a progress notification was
  /// printed.
  int _lastProgressSkipped = 0;

  /// The size of `_engine.failed` last time a progress notification was
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

  final StringSink _sink;

  /// Watches the tests run by [engine] and prints their results to the
  /// terminal.
  ///
  /// If [color] is `true`, this will use terminal colors; if it's `false`, it
  /// won't. If [printPath] is `true`, this will print the path name as part of
  /// the test description. Likewise, if [printPlatform] is `true`, this will
  /// print the platform as part of the test description.
  static FailuresOnlyReporter watch(
    Engine engine,
    StringSink sink, {
    required bool color,
    required bool printPath,
    required bool printPlatform,
  }) => FailuresOnlyReporter._(
    engine,
    sink,
    color: color,
    printPath: printPath,
    printPlatform: printPlatform,
  );

  FailuresOnlyReporter._(
    this._engine,
    this._sink, {
    required bool color,
    required bool printPath,
    required bool printPlatform,
  }) : _printPath = printPath,
       _printPlatform = printPlatform,
       _color = color,
       _green = color ? '\u001b[32m' : '',
       _red = color ? '\u001b[31m' : '',
       _yellow = color ? '\u001b[33m' : '',
       _gray = color ? '\u001b[90m' : '',
       _bold = color ? '\u001b[1m' : '',
       _noColor = color ? '\u001b[0m' : '' {
    _subscriptions.add(_engine.onTestStarted.listen(_onTestStarted));

    // Convert the future to a stream so that the subscription can be paused or
    // canceled.
    _subscriptions.add(_engine.success.asStream().listen(_onDone));
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
    _subscriptions.add(
      liveTest.onError.listen(
        (error) => _onError(liveTest, error.error, error.stackTrace),
      ),
    );

    _subscriptions.add(
      liveTest.onMessage.listen((message) {
        // TODO - Should this suppress output? Behave like printOnFailure?
        _progressLine(_description(liveTest));
        var text = message.text;
        if (message.type == MessageType.skip) text = '  $_yellow$text$_noColor';
        _sink.writeln(text);
      }),
    );
  }

  /// A callback called when [liveTest] throws [error].
  void _onError(LiveTest liveTest, Object error, StackTrace stackTrace) {
    if (!liveTest.test.metadata.chainStackTraces &&
        !liveTest.suite.isLoadSuite) {
      _shouldPrintStackTraceChainingNotice = true;
    }

    if (liveTest.state.status != Status.complete) return;

    _progressLine(_description(liveTest), suffix: ' $_bold$_red[E]$_noColor');

    if (error is! LoadException) {
      _sink
        ..writeln(indent('$error'))
        ..writeln(indent('$stackTrace'));
      return;
    }

    // TODO - what type is this?
    _sink.writeln(indent(error.toString(color: _color)));

    // Only print stack traces for load errors that come from the user's code.
    if (error.innerError is! FormatException && error.innerError is! String) {
      _sink.writeln(indent('$stackTrace'));
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

    if (_engine.liveTests.isEmpty) {
      _sink.writeln('No tests ran.');
    } else if (!success) {
      for (var liveTest in _engine.active) {
        _progressLine(
          _description(liveTest),
          suffix: ' - did not complete $_bold$_red[E]$_noColor',
        );
      }
      _progressLine('Some tests failed.', color: _red);
    } else if (_engine.passed.isEmpty) {
      _progressLine('All tests skipped.');
    } else {
      _progressLine('All tests passed!');
    }

    if (_shouldPrintStackTraceChainingNotice) {
      _sink
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
    if (_engine.passed.length == _lastProgressPassed &&
        _engine.skipped.length == _lastProgressSkipped &&
        _engine.failed.length == _lastProgressFailed &&
        message == _lastProgressMessage &&
        // Don't re-print just because a suffix was removed.
        (suffix == null || suffix == _lastProgressSuffix)) {
      return;
    }

    _lastProgressPassed = _engine.passed.length;
    _lastProgressSkipped = _engine.skipped.length;
    _lastProgressFailed = _engine.failed.length;
    _lastProgressMessage = message;
    _lastProgressSuffix = suffix;

    if (suffix != null) message += suffix;
    color ??= '';
    var buffer = StringBuffer();

    buffer.write(_green);
    buffer.write('+');
    buffer.write(_engine.passed.length);
    buffer.write(_noColor);

    if (_engine.skipped.isNotEmpty) {
      buffer.write(_yellow);
      buffer.write(' ~');
      buffer.write(_engine.skipped.length);
      buffer.write(_noColor);
    }

    if (_engine.failed.isNotEmpty) {
      buffer.write(_red);
      buffer.write(' -');
      buffer.write(_engine.failed.length);
      buffer.write(_noColor);
    }

    buffer.write(': ');
    buffer.write(color);
    buffer.write(message);
    buffer.write(_noColor);

    _sink.writeln(buffer.toString());
  }

  /// Returns a description of [liveTest].
  ///
  /// This differs from the test's own description in that it may also include
  /// the suite's name.
  String _description(LiveTest liveTest) {
    var name = liveTest.test.name;

    if (_printPath &&
        liveTest.suite is! LoadSuite &&
        liveTest.suite.path != null) {
      name = '${liveTest.suite.path}: $name';
    }

    if (_printPlatform) {
      name =
          '[${liveTest.suite.platform.runtime.name}, '
          '${liveTest.suite.platform.compiler.name}] $name';
    }

    if (liveTest.suite is LoadSuite) name = '$_bold$_gray$name$_noColor';

    return name;
  }
}
