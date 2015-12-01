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
import 'runner/reporter/json.dart';
import 'runner/runner_suite.dart';
import 'util/io.dart';
import 'utils.dart';

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

    var reporter;
    switch (config.reporter) {
      case "compact":
      case "expanded":
        var watch = config.reporter == "compact"
            ? CompactReporter.watch
            : ExpandedReporter.watch;

        reporter = watch(
            engine,
            color: config.color,
            verboseTrace: config.verboseTrace,
            printPath: config.paths.length > 1 ||
                new Directory(config.paths.single).existsSync(),
            printPlatform: config.platforms.length > 1);
        break;

      case "json":
        reporter = JsonReporter.watch(engine,
            verboseTrace: config.verboseTrace);
        break;
    }

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
        return suite.filter((test) {
          // Warn if any test has tags that don't appear on the command line.
          //
          // TODO(nweiz): Only print this once per test, even if it's run on
          // multiple runners.
          //
          // TODO(nweiz): If groups or suites are tagged, don't print this for
          // every test they contain.
          //
          // TODO(nweiz): Print this as part of the test's output so it's easy
          // to associate with the correct test.
          var specifiedTags = _config.tags.union(_config.excludeTags);
          var unrecognizedTags = test.metadata.tags.difference(specifiedTags);
          if (unrecognizedTags.isNotEmpty) {
            // Pause the reporter while we print to ensure that we don't
            // interfere with its output.
            _reporter.pause();
            warn(
                'Unknown ${pluralize('tag', unrecognizedTags.length)} '
                '${toSentence(unrecognizedTags)} in test "${test.name}".',
                color: _config.color);
            _reporter.resume();
          }

          // Skip any tests that don't match the given pattern.
          if (_config.pattern != null && !test.name.contains(_config.pattern)) {
            return false;
          }

          // If the user provided tags, skip tests that don't match all of them.
          if (!_config.tags.isEmpty &&
              !test.metadata.tags.containsAll(_config.tags)) {
            return false;
          }

          // Skip tests that do match any tags the user wants to exclude.
          if (_config.excludeTags.intersection(test.metadata.tags).isNotEmpty) {
            return false;
          }

          return true;
        });
      });
    });
  }

  /// Loads each suite in [suites] in order, pausing after load for platforms
  /// that support debugging.
  Future<bool> _loadThenPause(Stream<LoadSuite> suites) async {
    if (_config.platforms.contains(TestPlatform.vm)) {
      warn("Debugging is currently unsupported on the Dart VM.",
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
    if (suite.platform == TestPlatform.vm) return;

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

      if (suite.platform.isHeadless) {
        var url = suite.environment.remoteDebuggerUrl;
        if (url == null) {
          print("${yellow}Remote debugger URL not found.$noColor");
        } else {
          print("Remote debugger URL: $bold$url$noColor");
        }
      }

      var buffer = new StringBuffer(
          "${bold}The test runner is paused.${noColor} ");
      if (!suite.platform.isHeadless) {
        buffer.write("Open the dev console in ${suite.platform} ");
      } else {
        buffer.write("Open the remote debugger ");
      }
      if (suite.platform.isDartVM) buffer.write("or the Observatory ");

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
