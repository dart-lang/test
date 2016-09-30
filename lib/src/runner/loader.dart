// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart' hide Configuration;
import 'package:async/async.dart';
import 'package:path/path.dart' as p;

import '../backend/group.dart';
import '../backend/invoker.dart';
import '../backend/metadata.dart';
import '../backend/test_platform.dart';
import '../util/io.dart';
import '../utils.dart';
import 'browser/platform.dart';
import 'configuration.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'parse_metadata.dart';
import 'plugin/environment.dart';
import 'plugin/hack_register_platform.dart';
import 'plugin/platform.dart';
import 'runner_suite.dart';
import 'vm/platform.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// The test runner configuration.
  final _config = Configuration.current;

  /// All suites that have been created by the loader.
  final _suites = new Set<RunnerSuite>();

  /// Memoizers for platform plugins, indexed by the platforms they support.
  final _platformPlugins = <TestPlatform, AsyncMemoizer<PlatformPlugin>>{};

  /// The functions to use to load [_platformPlugins].
  ///
  /// These are passed to the plugins' async memoizers when a plugin is needed.
  final _platformCallbacks = <TestPlatform, AsyncFunction>{};

  /// Creates a new loader that loads tests on platforms defined in
  /// [Configuration.current].
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  Loader({String root}) {
    registerPlatformPlugin([TestPlatform.vm], () => new VMPlatform());
    registerPlatformPlugin([
      TestPlatform.dartium,
      TestPlatform.contentShell,
      TestPlatform.chrome,
      TestPlatform.phantomJS,
      TestPlatform.firefox,
      TestPlatform.safari,
      TestPlatform.internetExplorer
    ], () => BrowserPlatform.start(root: root));

    platformCallbacks.forEach((platform, plugin) {
      registerPlatformPlugin([platform], plugin);
    });
  }

  /// Registers a [PlatformPlugin] for [platforms].
  ///
  /// When the runner first requests that a suite be loaded for one of the given
  /// platforms, this will call [getPlugin] to load the platform plugin. It may
  /// return either a [PlatformPlugin] or a [Future<PlatformPlugin>]. That
  /// plugin is then preserved and used to load all suites for all matching
  /// platforms.
  ///
  /// This overwrites previous plugins for those platforms.
  void registerPlatformPlugin(Iterable<TestPlatform> platforms, getPlugin()) {
    var memoizer = new AsyncMemoizer<PlatformPlugin>();
    for (var platform in platforms) {
      _platformPlugins[platform] = memoizer;
      _platformCallbacks[platform] = getPlugin;
    }
  }

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that match the configuration's filename
  /// glob. Any tests that fail to load will be emitted as [LoadException]s.
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  ///
  /// If [platforms] is passed, these suites will only be loaded on those
  /// platforms. It must be a subset of the current configuration's platforms.
  /// Note that the suites aren't guaranteed to be loaded on all platforms in
  /// [platforms]: their `@TestOn` declarations are still respected.
  Stream<LoadSuite> loadDir(String dir, {Iterable<TestPlatform> platforms}) {
    platforms = _validatePlatformSubset(platforms);
    return StreamGroup.merge(new Directory(dir).listSync(recursive: true)
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
  /// If [platforms] is passed, these suites will only be loaded on those
  /// platforms. It must be a subset of the current configuration's platforms.
  /// Note that the suites aren't guaranteed to be loaded on all platforms in
  /// [platforms]: their `@TestOn` declarations are still respected.
  ///
  /// This will emit a [LoadException] if the file fails to load.
  Stream<LoadSuite> loadFile(String path, {Iterable<TestPlatform> platforms}) =>
      // Ensure that the right config is current when invoking platform plugins.
      _config.asCurrent(() async* {
    platforms = _validatePlatformSubset(platforms);

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

    for (var platform in platforms ?? _config.platforms) {
      if (!suiteMetadata.testOn.evaluate(platform, os: currentOS)) continue;

      var metadata = suiteMetadata.forPlatform(platform, os: currentOS);

      // Don't load a skipped suite.
      if (metadata.skip && !_config.runSkipped) {
        yield new LoadSuite.forSuite(new RunnerSuite(
            const PluginEnvironment(),
            new Group.root(
                [new LocalTest("(suite)", metadata, () {})],
                metadata: metadata),
            path: path, platform: platform));
        continue;
      }

      var name = (platform.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, () async {
        var memo = _platformPlugins[platform];

        try {
          var plugin = await memo.runOnce(_platformCallbacks[platform]);
          var suite = await plugin.load(path, platform, metadata);
          _suites.add(suite);
          return suite;
        } catch (error, stackTrace) {
          if (error is LoadException) rethrow;
          await new Future.error(new LoadException(path, error), stackTrace);
        }
      }, path: path, platform: platform);
    }
  });

  /// Asserts that [platforms] is a subset of [_config.platforms], and returns
  /// it as a set.
  ///
  /// Returns `null` if [platforms] is `null`.
  Set<TestPlatform> _validatePlatformSubset(Iterable<TestPlatform> platforms) {
    if (platforms == null) return null;
    platforms = platforms.toSet();
    if (platforms.every(_config.platforms.contains)) return platforms;
    throw new ArgumentError.value(platforms, 'platforms',
        "must be a subset of ${_config.platforms}.");
  }

  Future closeEphemeral() async {
    await Future.wait(_platformPlugins.values.map((memo) async {
      if (!memo.hasRun) return;
      await (await memo.future).closeEphemeral();
    }));
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() => _closeMemo.runOnce(() async {
    await Future.wait([
      Future.wait(_platformPlugins.values.map((memo) async {
        if (!memo.hasRun) return;
        await (await memo.future).close();
      })),
      Future.wait(_suites.map((suite) => suite.close()))
    ]);

    _platformPlugins.clear();
    _platformCallbacks.clear();
    _suites.clear();
  });
  final _closeMemo = new AsyncMemoizer();
}
