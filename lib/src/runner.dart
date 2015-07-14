// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner;

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'backend/metadata.dart';
import 'runner/application_exception.dart';
import 'runner/configuration.dart';
import 'runner/engine.dart';
import 'runner/load_exception.dart';
import 'runner/load_suite.dart';
import 'runner/loader.dart';
import 'runner/reporter/compact.dart';
import 'runner/reporter/expanded.dart';
import 'util/async_thunk.dart';
import 'utils.dart';

/// A class that loads and runs tests based on a [Configuration].
///
/// This maintains a [Loader] and an [Engine] and passes test suites from one to
/// the other, as well as printing out tests with a [CompactReporter] or an
/// [ExpandedReporter].
class Runner {
  /// The configuration for the runner.
  final Configuration _configuration;

  /// The loader that loads the test suites from the filesystem.
  final Loader _loader;

  /// The engine that runs the test suites.
  final Engine _engine;

  /// The thunk for ensuring [close] only runs once.
  final _closeThunk = new AsyncThunk();
  bool get _closed => _closeThunk.hasRun;

  /// Whether [run] has been called.
  bool _hasRun = false;

  /// Creates a new runner based on [configuration].
  factory Runner(Configuration configuration) {
    var metadata = new Metadata(
        verboseTrace: configuration.verboseTrace);
    var loader = new Loader(configuration.platforms,
        pubServeUrl: configuration.pubServeUrl,
        packageRoot: configuration.packageRoot,
        color: configuration.color,
        metadata: metadata,
        jsTrace: configuration.jsTrace);

    var engine = new Engine(concurrency: configuration.concurrency);

    var watch = configuration.reporter == "compact"
        ? CompactReporter.watch
        : ExpandedReporter.watch;

    watch(
        engine,
        color: configuration.color,
        verboseTrace: configuration.verboseTrace,
        printPath: configuration.paths.length > 1 ||
            new Directory(configuration.paths.single).existsSync(),
        printPlatform: configuration.platforms.length > 1);

    return new Runner._(configuration, loader, engine);
  }

  Runner._(this._configuration, this._loader, this._engine);

  /// Starts the runner.
  ///
  /// This starts running tests and printing their progress. It returns whether
  /// or not they ran successfully.
  Future<bool> run() async {
    _hasRun = true;

    if (_closed) {
      throw new StateError("run() may not be called on a closed Runner.");
    }

    var success;
    var results = await Future.wait([
      _loadSuites(),
      _engine.run()
    ], eagerError: true);
    success = results.last;

    if (_closed) return false;

    if (_engine.passed.length == 0 && _engine.failed.length == 0 &&
        _engine.skipped.length == 0 && _configuration.pattern != null) {
      var message = 'No tests match ';

      if (_configuration.pattern is RegExp) {
        var pattern = (_configuration.pattern as RegExp).pattern;
        message += 'regular expression "$pattern".';
      } else {
        message += '"${_configuration.pattern}".';
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
  Future close() => _closeThunk.run(() async {
    var timer;
    if (_hasRun) {
      // Wait a bit to print this message, since printing it eagerly looks weird
      // if the tests then finish immediately.
      timer = new Timer(new Duration(seconds: 1), () {
        // Print a blank line first to ensure that this doesn't interfere with
        // the compact reporter's unfinished line.
        print('');
        print("Waiting for current test(s) to finish.");
        print("Press Control-C again to terminate immediately.");
      });
    }

    // Make sure we close the engine *before* the loader. Otherwise,
    // LoadSuites provided by the loader may get into bad states.
    await _engine.close();
    if (timer != null) timer.cancel();
    await _loader.close();
  });

  /// Load the test suites in [_configuration.paths] that match
  /// [_configuration.pattern].
  Future _loadSuites() async {
    var group = new FutureGroup();

    mergeStreams(_configuration.paths.map((path) {
      if (new Directory(path).existsSync()) return _loader.loadDir(path);
      if (new File(path).existsSync()) return _loader.loadFile(path);

      return new Stream.fromIterable([
        new LoadSuite("loading $path", () =>
            throw new LoadException(path, 'Does not exist.'))
      ]);
    })).listen((loadSuite) {
      group.add(new Future.sync(() {
        _engine.suiteSink.add(loadSuite.changeSuite((suite) {
          if (_configuration.pattern == null) return suite;
          return suite.change(tests: suite.tests.where(
              (test) => test.name.contains(_configuration.pattern)));
        }));
      }));
    }, onError: (error, stackTrace) {
      group.add(new Future.error(error, stackTrace));
    }, onDone: group.close);

    await group.future;

    // Once we've loaded all the suites, notify the engine that no more will be
    // coming.
    _engine.suiteSink.close();
  }
}
