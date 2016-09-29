// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';

import '../util/io.dart';
import '../utils.dart';
import 'configuration.dart';
import 'console.dart';
import 'engine.dart';
import 'load_suite.dart';
import 'reporter.dart';
import 'runner_suite.dart';

/// Runs [loadSuite] in debugging mode.
///
/// Runs the suite's tests using [engine]. The [reporter] should already be
/// watching [engine], and the [config] should contain the user configuration
/// for the test runner.
///
/// Returns a [CancelableOperation] that will complete once the suite has
/// finished running. If the operation is canceled, the debugger will clean up
/// any resources it allocated.
CancelableOperation debug(Engine engine, Reporter reporter,
    LoadSuite loadSuite) {
  var debugger;
  var canceled = false;
  return new CancelableOperation.fromFuture(() async {
    // Make the underlying suite null so that the engine doesn't start running
    // it immediately.
    engine.suiteSink.add(loadSuite.changeSuite((_) => null));

    var suite = await loadSuite.suite;
    if (canceled || suite == null) return;

    debugger = new _Debugger(engine, reporter, suite);
    await debugger.run();
  }(), onCancel: () {
    canceled = true;
    if (debugger != null) debugger.close();
  });
}

// TODO(nweiz): Test using the console and restarting a test once sdk#25369 is
// fixed and the VM service client is released and we can set Dartium
// breakpoints.
/// A debugger for a single test suite.
class _Debugger {
  /// The test runner configuration.
  final _config = Configuration.current;

  /// The engine that will run the suite.
  final Engine _engine;

  /// The reporter that's reporting [_engine]'s progress.
  final Reporter _reporter;

  /// The suite to run.
  final RunnerSuite _suite;

  /// The console through which the user can control the debugger.
  ///
  /// This is only visible when the test environment is paused, so as not to
  /// overlap with the reporter's reporting.
  final Console _console;

  /// The subscription to [_suite.onDebugging].
  StreamSubscription<bool> _onDebuggingSubscription;

  /// Whether [close] has been called.
  bool _closed = false;

  _Debugger(this._engine, this._reporter, this._suite)
      : _console = new Console(color: Configuration.current.color) {
    _console.registerCommand(
        "restart", "Restart the current test after it finishes running.",
        _restartTest);

    _onDebuggingSubscription = _suite.onDebugging.listen((debugging) {
      if (debugging) {
        _onDebugging();
      } else {
        _onNotDebugging();
      }
    });
  }

  /// Runs the debugger.
  ///
  /// This prints information about the suite's debugger, then once the user has
  /// had a chance to set breakpoints, runs the suite's tests.
  Future run() async {
    try {
      await _pause();
      if (_closed) return;

      _engine.suiteSink.add(_suite);
      await _engine.onIdle.first;
    } finally {
      close();
    }
  }

  /// Prints URLs for the [_suite]'s debugger and waits for the user to tell the
  /// suite to run.
  Future _pause() async {
    if (_suite.platform == null) return;
    if (!_suite.environment.supportsDebugging) return;

    try {
      _reporter.pause();

      var bold = _config.color ? '\u001b[1m' : '';
      var yellow = _config.color ? '\u001b[33m' : '';
      var noColor = _config.color ? '\u001b[0m' : '';
      print('');

      if (_suite.platform.isDartVM) {
        var url = _suite.environment.observatoryUrl;
        if (url == null) {
          print("${yellow}Observatory URL not found. Make sure you're using "
              "${_suite.platform.name} 1.11 or later.$noColor");
        } else {
          print("Observatory URL: $bold$url$noColor");
        }
      }

      if (_suite.platform.isHeadless) {
        var url = _suite.environment.remoteDebuggerUrl;
        if (url == null) {
          print("${yellow}Remote debugger URL not found.$noColor");
        } else {
          print("Remote debugger URL: $bold$url$noColor");
        }
      }

      var buffer = new StringBuffer(
          "${bold}The test runner is paused.${noColor} ");
      if (!_suite.platform.isHeadless) {
        buffer.write("Open the dev console in ${_suite.platform} ");
      } else {
        buffer.write("Open the remote debugger ");
      }
      if (_suite.platform.isDartVM) buffer.write("or the Observatory ");

      buffer.write("and set breakpoints. Once you're finished, return to this "
          "terminal and press Enter.");

      print(wordWrap(buffer.toString()));

      await inCompletionOrder([
        _suite.environment.displayPause(),
        cancelableNext(stdinLines)
      ]).first;
    } finally {
      _reporter.resume();
    }
  }

  /// Handles the environment pausing to debug.
  ///
  /// This starts the interactive console.
  void _onDebugging() {
    _reporter.pause();

    print('\nEntering debugging console. Type "help" for help.');
    _console.start();
  }

  /// Handles the environment starting up again.
  ///
  /// This closes the interactive console.
  void _onNotDebugging() {
    _reporter.resume();
    _console.stop();
  }

  /// Restarts the current test.
  void _restartTest() {
    var liveTest = _engine.active.single;
    _engine.restartTest(liveTest);
    print(wordWrap(
        'Will restart "${liveTest.test.name}" once it finishes running.'));
  }

  /// Closes the debugger and releases its resources.
  void close() {
    _closed = true;
    _onDebuggingSubscription.cancel();
    _console.stop();
  }
}
