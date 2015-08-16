// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.loader;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:async/async.dart';
import 'package:path/path.dart' as p;

import '../backend/invoker.dart';
import '../backend/metadata.dart';
import '../backend/test_platform.dart';
import '../util/io.dart';
import '../utils.dart';
import 'configuration.dart';
import 'browser/server.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'parse_metadata.dart';
import 'runner_suite.dart';
import 'vm/environment.dart';
import 'vm/isolate_loader.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// The test runner configuration.
  final Configuration _config;

  /// The root directory that will be served for browser tests.
  final String _root;

  /// The server that serves browser test pages.
  ///
  /// This is lazily initialized the first time it's accessed.
  Future<BrowserServer> get _browserServer {
    return _browserServerMemo.runOnce(() {
      return BrowserServer.start(_config, root: _root);
    });
  }
  final _browserServerMemo = new AsyncMemoizer<BrowserServer>();

  /// The loader for isolate-based test suites.
  ///
  /// This is lazily initialized the first time it's accessed.
  IsolateLoader get _isolateLoader {
    if (_isolateLoaderMemo == null)
      _isolateLoaderMemo = new IsolateLoader(_config);
    return _isolateLoaderMemo;
  }
  IsolateLoader _isolateLoaderMemo;

  /// The memoizer for running [close] exactly once.
  final _closeMemo = new AsyncMemoizer();

  /// Creates a new loader that loads tests on platforms defined in [_config].
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  Loader(this._config, {String root})
      : _root = root == null ? p.current : root;

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that end in "_test.dart". Any tests that
  /// fail to load will be emitted as [LoadException]s.
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  Stream<LoadSuite> loadDir(String dir) {
    return mergeStreams(new Directory(dir).listSync(recursive: true)
        .map((entry) {
      if (entry is! File) return new Stream.fromIterable([]);

      if (!entry.path.endsWith("_test.dart")) {
        return new Stream.fromIterable([]);
      }

      if (p.split(entry.path).contains('packages')) {
         return new Stream.fromIterable([]);
      }

      return loadFile(entry.path);
    }));
  }

  /// Loads a test suite from the file at [path].
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  ///
  /// This will emit a [LoadException] if the file fails to load.
  Stream<LoadSuite> loadFile(String path) async* {
    var suiteMetadata;
    try {
      suiteMetadata = parseMetadata(path);
    } on AnalyzerErrorGroup catch (_) {
      // Ignore the analyzer's error, since its formatting is much worse than
      // the VM's or dart2js's.
      suiteMetadata = new Metadata();
    } on FormatException catch (error, stackTrace) {
      yield new LoadSuite.forLoadException(
          new LoadException(path, error), stackTrace: stackTrace);
      return;
    }
    suiteMetadata = _config.metadata.merge(suiteMetadata);

    if (_config.pubServeUrl != null && !p.isWithin('test', path)) {
      yield new LoadSuite.forLoadException(new LoadException(
          path, 'When using "pub serve", all test files must be in test/.'));
      return;
    }

    for (var platform in _config.platforms) {
      if (!suiteMetadata.testOn.evaluate(platform, os: currentOS)) continue;

      var metadata = suiteMetadata.forPlatform(platform, os: currentOS);

      // Don't load a skipped suite.
      if (metadata.skip) {
        yield new LoadSuite.forSuite(new RunnerSuite(const VMEnvironment(), [
          new LocalTest(path, metadata, () {})
        ], path: path, platform: platform, metadata: metadata));
        continue;
      }

      var name = (platform.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, () {
        return platform == TestPlatform.vm
            ? _loadVmFile(path, metadata)
            : _loadBrowserFile(path, platform, metadata);
      }, platform: platform);
    }
  }

  /// Load the test suite at [path] in [platform].
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<RunnerSuite> _loadBrowserFile(String path, TestPlatform platform,
        Metadata metadata) async {
    return (await _browserServer).loadSuite(path, platform, metadata);
  }

  /// Load the test suite at [path] in VM isolate.
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<RunnerSuite> _loadVmFile(String path, Metadata metadata) {
    return _isolateLoader.loadSuite(path, metadata);
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() {
    return _closeMemo.runOnce(() async {
      if (_isolateLoaderMemo != null)
        await _isolateLoader.close();

      if (_browserServerMemo.hasRun)
        await (await _browserServer).close();
    });
  }
}
