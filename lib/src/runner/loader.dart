// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart' hide Configuration;
import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../backend/group.dart';
import '../backend/invoker.dart';
import '../backend/runtime.dart';
import '../util/io.dart';
import 'browser/platform.dart';
import 'configuration.dart';
import 'configuration/suite.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'node/platform.dart';
import 'parse_metadata.dart';
import 'plugin/customizable_platform.dart';
import 'plugin/environment.dart';
import 'plugin/hack_register_platform.dart';
import 'plugin/platform.dart';
import 'runner_suite.dart';
import 'vm/platform.dart';

// TODO(nweiz): Use inline function types when sdk#30858 is fixed.
typedef FutureOr<PlatformPlugin> _PlatformPluginFunction();

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// The test runner configuration.
  final _config = Configuration.current;

  /// All suites that have been created by the loader.
  final _suites = new Set<RunnerSuite>();

  /// Memoizers for platform plugins, indexed by the runtimes they support.
  final _platformPlugins = <Runtime, AsyncMemoizer<PlatformPlugin>>{};

  /// The functions to use to load [_platformPlugins].
  ///
  /// These are passed to the plugins' async memoizers when a plugin is needed.
  final _platformCallbacks = <Runtime, _PlatformPluginFunction>{};

  /// A map of all runtimes registered in [_platformCallbacks], indexed by
  /// their string identifiers.
  final _runtimesByIdentifier = <String, Runtime>{};

  /// The user-provided settings for runtimes, as a list of settings that will
  /// be merged together using [CustomizablePlatform.mergePlatformSettings].
  final _runtimeSettings = <Runtime, List<YamlMap>>{};

  /// The user-provided settings for runtimes.
  final _parsedRuntimeSettings = <Runtime, Object>{};

  /// All plaforms supported by this [Loader].
  List<Runtime> get allRuntimes =>
      new List.unmodifiable(_platformCallbacks.keys);

  /// The runtime variables supported by this loader, in addition the default
  /// variables that are always supported.
  Iterable<String> get _runtimeVariables =>
      _platformCallbacks.keys.map((runtime) => runtime.identifier);

  /// Creates a new loader that loads tests on platforms defined in
  /// [Configuration.current].
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  ///
  /// The [plugins] register [PlatformPlugin]s that are associated with the
  /// provided runtimes. When the runner first requests that a suite be loaded
  /// for one of the given runtimes, the lodaer will call the associated
  /// callback to load the platform plugin. That plugin is then preserved and
  /// used to load all suites for all matching runtimes. Platform plugins may
  /// override built-in runtimes.
  Loader(
      {String root, Map<Iterable<Runtime>, _PlatformPluginFunction> plugins}) {
    _registerPlatformPlugin([Runtime.vm], () => new VMPlatform());
    _registerPlatformPlugin([Runtime.nodeJS], () => new NodePlatform());
    _registerPlatformPlugin([
      Runtime.dartium,
      Runtime.contentShell,
      Runtime.chrome,
      Runtime.phantomJS,
      Runtime.firefox,
      Runtime.safari,
      Runtime.internetExplorer
    ], () => BrowserPlatform.start(root: root));

    platformCallbacks.forEach((runtime, plugin) {
      _registerPlatformPlugin([runtime], plugin);
    });

    plugins?.forEach(_registerPlatformPlugin);

    _registerCustomRuntimes();

    _config.validateRuntimes(allRuntimes);

    _registerRuntimeOverrides();
  }

  /// Registers a [PlatformPlugin] for [runtimes].
  void _registerPlatformPlugin(
      Iterable<Runtime> runtimes, FutureOr<PlatformPlugin> getPlugin()) {
    var memoizer = new AsyncMemoizer<PlatformPlugin>();
    for (var runtime in runtimes) {
      _platformPlugins[runtime] = memoizer;
      _platformCallbacks[runtime] = getPlugin;
      _runtimesByIdentifier[runtime.identifier] = runtime;
    }
  }

  /// Registers user-defined runtimes from [Configuration.defineRuntimes].
  void _registerCustomRuntimes() {
    for (var customRuntime in _config.defineRuntimes.values) {
      if (_runtimesByIdentifier.containsKey(customRuntime.identifier)) {
        throw new SourceSpanFormatException(
            wordWrap(
                'The platform "${customRuntime.identifier}" already exists. '
                'Use override_platforms to override it.'),
            customRuntime.identifierSpan);
      }

      var parent = _runtimesByIdentifier[customRuntime.parent];
      if (parent == null) {
        throw new SourceSpanFormatException(
            'Unknown platform.', customRuntime.parentSpan);
      }

      var runtime = parent.extend(customRuntime.name, customRuntime.identifier);
      _platformPlugins[runtime] = _platformPlugins[parent];
      _platformCallbacks[runtime] = _platformCallbacks[parent];
      _runtimesByIdentifier[runtime.identifier] = runtime;

      _runtimeSettings[runtime] = [customRuntime.settings];
    }
  }

  /// Registers users' runtime settings from [Configuration.overrideRuntimes].
  void _registerRuntimeOverrides() {
    for (var settings in _config.overrideRuntimes.values) {
      var runtime = _runtimesByIdentifier[settings.identifier];

      // This is officially validated in [Configuration.validateRuntimes].
      assert(runtime != null);

      _runtimeSettings.putIfAbsent(runtime, () => []).addAll(settings.settings);
    }
  }

  /// Returns the [Runtime] registered with this loader that's identified
  /// by [identifier], or `null` if none can be found.
  Runtime findRuntime(String identifier) => _runtimesByIdentifier[identifier];

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
          parseMetadata(path, _runtimeVariables.toSet())));
    } on AnalyzerErrorGroup catch (_) {
      // Ignore the analyzer's error, since its formatting is much worse than
      // the VM's or dart2js's.
    } on FormatException catch (error, stackTrace) {
      yield new LoadSuite.forLoadException(
          new LoadException(path, error), suiteConfig,
          stackTrace: stackTrace);
      return;
    }

    if (_config.suiteDefaults.excludeTags.evaluate(suiteConfig.metadata.tags)) {
      return;
    }

    if (_config.pubServeUrl != null && !p.isWithin('test', path)) {
      yield new LoadSuite.forLoadException(
          new LoadException(
              path, 'When using "pub serve", all test files must be in test/.'),
          suiteConfig);
      return;
    }

    for (var runtimeName in suiteConfig.runtimes) {
      var runtime = findRuntime(runtimeName);
      assert(runtime != null, 'Unknown platform "$runtimeName".');

      var platform = currentPlatform(runtime);
      if (!suiteConfig.metadata.testOn.evaluate(platform)) {
        continue;
      }

      var platformConfig = suiteConfig.forPlatform(platform);

      // Don't load a skipped suite.
      if (platformConfig.metadata.skip && !platformConfig.runSkipped) {
        yield new LoadSuite.forSuite(new RunnerSuite(
            const PluginEnvironment(),
            platformConfig,
            new Group.root(
                [new LocalTest("(suite)", platformConfig.metadata, () {})],
                metadata: platformConfig.metadata),
            platform,
            path: path));
        continue;
      }

      var name = (platform.runtime.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, platformConfig, platform, () async {
        if (platformConfig.precompiledPath != null &&
            !platform.runtime.isBrowser) {
          warn("--precompiled is only supported for browser platforms.",
              print: true);
        }

        var memo = _platformPlugins[platform.runtime];

        try {
          var plugin = await memo.runOnce(_platformCallbacks[platform.runtime]);
          _customizePlatform(plugin, platform.runtime);
          var suite = await plugin.load(path, platform, platformConfig,
              {"platformVariables": _runtimeVariables.toList()});
          if (suite != null) _suites.add(suite);
          return suite;
        } catch (error, stackTrace) {
          if (error is LoadException) rethrow;
          await new Future.error(new LoadException(path, error), stackTrace);
          return null;
        }
      }, path: path);
    }
  }

  /// Passes user-defined settings to [plugin] if necessary.
  void _customizePlatform(PlatformPlugin plugin, Runtime runtime) {
    var parsed = _parsedRuntimeSettings[runtime];
    if (parsed != null) {
      (plugin as CustomizablePlatform).customizePlatform(runtime, parsed);
      return;
    }

    var settings = _runtimeSettings[runtime];
    if (settings == null) return;

    if (plugin is CustomizablePlatform) {
      parsed = settings
          .map(plugin.parsePlatformSettings)
          .reduce(plugin.mergePlatformSettings);
      plugin.customizePlatform(runtime, parsed);
      _parsedRuntimeSettings[runtime] = parsed;
    } else {
      String identifier;
      SourceSpan span;
      if (runtime.isChild) {
        identifier = runtime.parent.identifier;
        span = _config.defineRuntimes[runtime.identifier].parentSpan;
      } else {
        identifier = runtime.identifier;
        span = _config.overrideRuntimes[runtime.identifier].identifierSpan;
      }

      throw new SourceSpanFormatException(
          'The "$identifier" platform can\'t be customized.', span);
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
