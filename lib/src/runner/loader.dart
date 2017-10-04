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
import '../backend/test_platform.dart';
import '../util/io.dart';
import '../utils.dart';
import 'browser/platform.dart';
import 'configuration.dart';
import 'configuration/suite.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'node/platform.dart';
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

  /// A map of all platforms registered in [_platformCallbacks], indexed by
  /// their string identifiers.
  final _platformsByIdentifier = <String, TestPlatform>{};

  /// All plaforms supported by this [Loader].
  List<TestPlatform> get allPlatforms =>
      new List.unmodifiable(_platformCallbacks.keys);

  List<Map<String, Object>> get _allPlatformsSerialized {
    if (__allPlatformsSerialized != null &&
        __allPlatformsSerialized.length == _platformCallbacks.length) {
      return __allPlatformsSerialized;
    }

    __allPlatformsSerialized = _platformCallbacks.keys
        .map((platform) => platform.serialize())
        .toList();
    return __allPlatformsSerialized;
  }

  List<Map<String, Object>> __allPlatformsSerialized;

  /// Creates a new loader that loads tests on platforms defined in
  /// [Configuration.current].
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  Loader({String root}) {
    registerPlatformPlugin([TestPlatform.vm], () => new VMPlatform());
    registerPlatformPlugin([TestPlatform.nodeJS], () => new NodePlatform());
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
      _platformsByIdentifier[platform.identifier] = platform;
    }
  }

  /// Returns the [TestPlatform] registered with this loader that's identified
  /// by [identifier], or `null` if none can be found.
  TestPlatform findTestPlatform(String identifier) =>
      _platformsByIdentifier[identifier];

  /// Loads all test suites in [dir] according to [suiteConfig].
  ///
  /// This will load tests from files that match the global configuration's
  /// filename glob. Any tests that fail to load will be emitted as
  /// [LoadException]s.
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  Stream<LoadSuite> loadDir(String dir, SuiteConfiguration suiteConfig) {
    return StreamGroup
        .merge(new Directory(dir).listSync(recursive: true).map((entry) {
      if (entry is! File) return new Stream.fromIterable([]);

      if (!_config.filename.matches(p.basename(entry.path))) {
        return new Stream.fromIterable([]);
      }

      if (p.split(entry.path).contains('packages')) {
        return new Stream.fromIterable([]);
      }

      return loadFile(entry.path, suiteConfig);
    }));
  }

  /// Loads a test suite from the file at [path] according to [suiteConfig].
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  ///
  /// This will emit a [LoadException] if the file fails to load.
  Stream<LoadSuite> loadFile(
      String path, SuiteConfiguration suiteConfig) async* {
    try {
      suiteConfig = suiteConfig.merge(new SuiteConfiguration.fromMetadata(
          parseMetadata(path, allPlatforms)));
    } on AnalyzerErrorGroup catch (_) {
      // Ignore the analyzer's error, since its formatting is much worse than
      // the VM's or dart2js's.
    } on FormatException catch (error, stackTrace) {
      yield new LoadSuite.forLoadException(
          new LoadException(path, error), suiteConfig,
          stackTrace: stackTrace);
      return;
    }

    if (_config.pubServeUrl != null && !p.isWithin('test', path)) {
      yield new LoadSuite.forLoadException(
          new LoadException(
              path, 'When using "pub serve", all test files must be in test/.'),
          suiteConfig);
      return;
    }

    for (var platformName in suiteConfig.platforms) {
      var platform = findTestPlatform(platformName);
      assert(platform != null, 'Unknown platform "$platformName".');

      if (!suiteConfig.metadata.testOn.evaluate(platform, os: currentOS)) {
        continue;
      }

      var platformConfig = suiteConfig.forPlatform(platform, os: currentOS);

      // Don't load a skipped suite.
      if (platformConfig.metadata.skip && !platformConfig.runSkipped) {
        yield new LoadSuite.forSuite(new RunnerSuite(
            const PluginEnvironment(),
            platformConfig,
            new Group.root(
                [new LocalTest("(suite)", platformConfig.metadata, () {})],
                metadata: platformConfig.metadata),
            path: path,
            platform: platform));
        continue;
      }

      var name = (platform.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, platformConfig, () async {
        var memo = _platformPlugins[platform];

        try {
          var plugin = await memo.runOnce(_platformCallbacks[platform]);
          var suite = await plugin.load(path, platform, platformConfig,
              {"testPlatforms": _allPlatformsSerialized});
          if (suite != null) _suites.add(suite);
          return suite;
        } catch (error, stackTrace) {
          if (error is LoadException) rethrow;
          await new Future.error(new LoadException(path, error), stackTrace);
          return null;
        }
      }, path: path, platform: platform);
    }
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
