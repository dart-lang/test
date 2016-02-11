// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart' hide Configuration;
import 'package:async/async.dart';
import 'package:path/path.dart' as p;

import '../backend/group.dart';
import '../backend/metadata.dart';
import '../backend/test_platform.dart';
import '../util/io.dart';
import '../utils.dart';
import 'browser/server.dart';
import 'configuration.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'parse_metadata.dart';
import 'plugin/environment.dart';
import 'plugin/platform.dart';
import 'runner_suite.dart';
import 'vm/platform.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// The test runner configuration.
  final Configuration _config;

  /// The root directory that will be served for browser tests.
  final String _root;

  /// All suites that have been created by the loader.
  final _suites = new Set<RunnerSuite>();

  /// Plugins for loading test suites for various platforms.
  ///
  /// This includes the built-in [VMPlatform] plugin.
  final _platformPlugins = <TestPlatform, PlatformPlugin>{};

  /// The server that serves browser test pages.
  ///
  /// This is lazily initialized the first time it's accessed.
  Future<BrowserServer> get _browserServer {
    return _browserServerMemo.runOnce(() {
      return BrowserServer.start(_config, root: _root);
    });
  }
  final _browserServerMemo = new AsyncMemoizer<BrowserServer>();

  /// The memoizer for running [close] exactly once.
  final _closeMemo = new AsyncMemoizer();

  /// Creates a new loader that loads tests on platforms defined in [_config].
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  Loader(this._config, {String root})
      : _root = root == null ? p.current : root {
    registerPlatformPlugin(new VMPlatform(_config));
  }

  /// Registers [plugin] as a plugin for the platforms it defines in
  /// [PlatformPlugin.platforms].
  ///
  /// This overwrites previous plugins for those platforms.
  void registerPlatformPlugin(PlatformPlugin plugin) {
    for (var platform in plugin.platforms) {
      _platformPlugins[platform] = plugin;
    }
  }

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that match the configuration's filename
  /// glob. Any tests that fail to load will be emitted as [LoadException]s.
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  Stream<LoadSuite> loadDir(String dir) {
    return mergeStreams(new Directory(dir).listSync(recursive: true)
        .map((entry) {
      if (entry is! File) return new Stream.fromIterable([]);

      if (!_config.filename.matches(p.basename(entry.path))) {
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
        yield new LoadSuite.forSuite(new RunnerSuite(
            const PluginEnvironment(),
            new Group.root([], metadata: metadata),
            path: path, platform: platform));
        continue;
      }

      var name = (platform.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, () async {
        var plugin = _platformPlugins[platform];

        if (plugin != null) {
          try {
            return await plugin.load(path, platform, metadata);
          } catch (error, stackTrace) {
            if (error is LoadException) rethrow;
            await new Future.error(new LoadException(path, error), stackTrace);
          }
        }

        assert(platform.isBrowser);
        return _loadBrowserFile(path, platform, metadata);
      }, path: path, platform: platform);
    }
  }

  /// Load the test suite at [path] in [platform].
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<RunnerSuite> _loadBrowserFile(String path, TestPlatform platform,
        Metadata metadata) async =>
      (await _browserServer).loadSuite(path, platform, metadata);

  /// Close all the browsers that the loader currently has open.
  ///
  /// Note that this doesn't close the loader itself. Browser tests can still be
  /// loaded, they'll just spawn new browsers.
  Future closeBrowsers() async {
    if (!_browserServerMemo.hasRun) return;
    await (await _browserServer).closeBrowsers();
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() {
    return _closeMemo.runOnce(() async {
      await Future.wait(_suites.map((suite) => suite.close()));
      _suites.clear();

      if (!_browserServerMemo.hasRun) return;
      await (await _browserServer).close();
    });
  }
}
