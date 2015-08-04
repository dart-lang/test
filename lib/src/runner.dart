// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner;

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'backend/test_platform.dart';
import 'runner/application_exception.dart';
import 'runner/configuration.dart';
import 'runner/engine.dart';
import 'runner/load_exception.dart';
import 'runner/load_suite.dart';
import 'runner/loader.dart';
import 'runner/reporter.dart';
import 'runner/reporter/compact.dart';
import 'runner/reporter/expanded.dart';
import 'runner/runner_suite.dart';
import 'util/io.dart';
import 'utils.dart';

/// The set of platforms for which debug flags are (currently) not supported.
final _debugUnsupportedPlatforms = new Set.from(
    [TestPlatform.vm, TestPlatform.phantomJS]);

/// A class that loads and runs tests based on a [Configuration].
///
/// This maintains a [Loader] and an [Engine] and passes test suites from one to
/// the other, as well as printing out tests with a [CompactReporter] or an
/// [ExpandedReporter].
class Runner {
  /// The configuration for the runner.
  final Configuration _config;

  /// The loader that loads the test suites from the filesystem.
  final Loader _loader;

  /// The engine that runs the test suites.
  final Engine _engine;

  /// The reporter that's emitting the test runner's results.
  final Reporter _reporter;

  /// The subscription to the stream returned by [_loadSuites].
  StreamSubscription _suiteSubscription;

  /// The memoizer for ensuring [close] only runs once.
  final _closeMemo = new AsyncMemoizer();
  bool get _closed => _closeMemo.hasRun;

  /// Creates a new runner based on [configuration].
  factory Runner(Configuration config) {
    var loader = new Loader(config);
    var engine = new Engine(concurrency: config.concurrency);

    var watch = config.reporter == "compact"
        ? CompactReporter.watch
        : ExpandedReporter.watch;

    var reporter = watch(
        engine,
        color: config.color,
        verboseTrace: config.verboseTrace,
        printPath: config.paths.length > 1 ||
            new Directory(config.paths.single).existsSync(),
        printPlatform: config.platforms.length > 1);

    return new Runner._(config, loader, engine, reporter);
  }

  Runner._(this._config, this._loader, this._engine, this._reporter);

  /// Starts the runner.
  ///
  /// This starts running tests and printing their progress. It returns whether
  /// or not they ran successfully.
  Future<bool> run() async {
    if (_closed) {
      throw new StateError("run() may not be called on a closed Runner.");
    }

    var suites = _loadSuites();

    var success;
    if (_config.pauseAfterLoad) {
      success = await _loadThenPause(suites);
    } else {
      _suiteSubscription = suites.listen(_engine.suiteSink.add);
      var results = await Future.wait([
        _suiteSubscription.asFuture().then((_) => _engine.suiteSink.close()),
        _engine.run()
      ], eagerError: true);
      success = results.last;
    }

    if (_closed) return false;

    if (_engine.passed.length == 0 && _engine.failed.length == 0 &&
        _engine.skipped.length == 0 && _config.pattern != null) {
      var message = 'No tests match ';

      if (_config.pattern is RegExp) {
        var pattern = (_config.pattern as RegExp).pattern;
        message += 'regular expression "$pattern".';
      } else {
        message += '"${_config.pattern}".';
      }
      throw new ApplicationException(message);
    }

    // Explicitly check "== true" here because [Engine.run] can return `null`
    // if the engine was closed prematurely.
    return success == true;
  }

  /// Closes the runner.
  ///
  /// This stops any future test suites from running. It will wait for any
  /// currently-running VM tests, in case they have stuff to clean up on the
  /// filesystem.
  Future close() => _closeMemo.runOnce(() async {
    var timer;
    if (!_engine.isIdle) {
      // Wait a bit to print this message, since printing it eagerly looks weird
      // if the tests then finish immediately.
      timer = new Timer(new Duration(seconds: 1), () {
        // Pause the reporter while we print to ensure that we don't interfere
        // with its output.
        _reporter.pause();
        print("Waiting for current test(s) to finish.");
        print("Press Control-C again to terminate immediately.");
        _reporter.resume();
      });
    }

    if (_suiteSubscription != null) _suiteSubscription.cancel();
    _suiteSubscription = null;

    // Make sure we close the engine *before* the loader. Otherwise,
    // LoadSuites provided by the loader may get into bad states.
    await _engine.close();
    if (timer != null) timer.cancel();
    await _loader.close();
  });

  /// Return a stream of [LoadSuite]s in [_config.paths].
  ///
  /// Only tests that match [_config.pattern] will be included in the
  /// suites once they're loaded.
  Stream<LoadSuite> _loadSuites() {
    return mergeStreams(_config.paths.map((path) {
      if (new Directory(path).existsSync()) return _loader.loadDir(path);
      if (new File(path).existsSync()) return _loader.loadFile(path);

      return new Stream.fromIterable([
        new LoadSuite("loading $path", () =>
            throw new LoadException(path, 'Does not exist.'))
      ]);
    })).map((loadSuite) {
      return loadSuite.changeSuite((suite) {
        if (_config.pattern == null) return suite;
        return suite.change(tests: suite.tests.where((test) =>
            test.name.contains(_config.pattern)));
      });
    });
  }

  /// Loads each suite in [suites] in order, pausing after load for platforms
  /// that support debugging.
  Future<bool> _loadThenPause(Stream<LoadSuite> suites) async {
    var unsupportedPlatforms = _config.platforms
        .where(_debugUnsupportedPlatforms.contains)
        .map((platform) =>
             platform == TestPlatform.vm ? "the Dart VM" : platform.name)
        .toList();

    if (unsupportedPlatforms.isNotEmpty) {
      warn(
          wordWrap("Debugging is currently unsupported on "
              "${toSentence(unsupportedPlatforms)}."),
          color: _config.color);
    }

    _suiteSubscription = suites.asyncMap((loadSuite) async {
      // Make the underlying suite null so that the engine doesn't start running
      // it immediately.
      _engine.suiteSink.add(loadSuite.changeSuite((_) => null));

      var suite = await loadSuite.suite;
      if (suite == null) return;

      await _pause(suite);
      if (_closed) return;

      _engine.suiteSink.add(suite);
      await _engine.onIdle.first;
    }).listen(null);

    var results = await Future.wait([
      _suiteSubscription.asFuture().then((_) => _engine.suiteSink.close()),
      _engine.run()
    ]);
    return results.last;
  }

  /// Pauses the engine and the reporter so that the user can set breakpoints as
  /// necessary.
  ///
  /// This is a no-op for test suites that aren't on platforms where debugging
  /// is supported.
  Future _pause(RunnerSuite suite) async {
    if (suite.platform == null) return;
    if (_debugUnsupportedPlatforms.contains(suite.platform)) return;

    try {
      _reporter.pause();

      var bold = _config.color ? '\u001b[1m' : '';
      var yellow = _config.color ? '\u001b[33m' : '';
      var noColor = _config.color ? '\u001b[0m' : '';
      print('');

      if (suite.platform.isDartVM) {
        var url = suite.environment.observatoryUrl;
        if (url == null) {
          print("${yellow}Observatory URL not found. Make sure you're using "
              "${suite.platform.name} 1.11 or later.$noColor");
        } else {
          print("Observatory URL: $bold$url$noColor");
        }
      }

      var buffer = new StringBuffer(
          "${bold}The test runner is paused.${noColor} ");
      if (!suite.platform.isHeadless) {
        buffer.write("Open the dev console in ${suite.platform} ");
        if (suite.platform.isDartVM) buffer.write("or ");
      } else {
        buffer.write("Open ");
      }
      if (suite.platform.isDartVM) buffer.write("the Observatory ");

      buffer.write("and set breakpoints. Once you're finished, return to this "
          "terminal and press Enter.");

      print(wordWrap(buffer.toString()));

      await inCompletionOrder([
        suite.environment.displayPause(),
        cancelableNext(stdinLines)
      ]).first;
    } finally {
      _reporter.resume();
    }
  }
}
