// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:boolean_selector/boolean_selector.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../backend/metadata.dart';
import '../backend/platform_selector.dart';
import '../backend/test_platform.dart';
import '../frontend/timeout.dart';
import '../util/io.dart';
import 'configuration/args.dart' as args;
import 'configuration/load.dart';
import 'configuration/values.dart';

/// The key used to look up [Configuration.current] in a zone.
final _currentKey = new Object();

/// A class that encapsulates the command-line configuration of the test runner.
class Configuration {
  /// An empty configuration with only default values.
  ///
  /// Using this is slightly more efficient than manually constructing a new
  /// configuration with no arguments.
  static final empty = new Configuration._();

  /// The usage string for the command-line arguments.
  static String get usage => args.usage;

  /// Whether `--help` was passed.
  bool get help => _help ?? false;
  final bool _help;

  /// Whether `--version` was passed.
  bool get version => _version ?? false;
  final bool _version;

  /// Whether stack traces should be presented as-is or folded to remove
  /// irrelevant packages.
  bool get verboseTrace => _verboseTrace ?? false;
  final bool _verboseTrace;

  /// Whether JavaScript stack traces should be left as-is or converted to
  /// Dart-like traces.
  bool get jsTrace => _jsTrace ?? false;
  final bool _jsTrace;

  /// Whether tests should be skipped.
  bool get skip => _skip ?? false;
  final bool _skip;

  /// The reason tests or suites should be skipped, if given.
  final String skipReason;

  /// Whether skipped tests should be run.
  bool get runSkipped => _runSkipped ?? false;
  final bool _runSkipped;

  /// The selector indicating which platforms the tests support.
  ///
  /// When [merge]d, this is intersected with the other configuration's
  /// supported platforms.
  final PlatformSelector testOn;

  /// Whether to pause for debugging after loading each test suite.
  bool get pauseAfterLoad => _pauseAfterLoad ?? false;
  final bool _pauseAfterLoad;

  /// The path to dart2js.
  String get dart2jsPath => _dart2jsPath ?? p.join(sdkDir, 'bin', 'dart2js');
  final String _dart2jsPath;

  /// Additional arguments to pass to dart2js.
  final List<String> dart2jsArgs;

  /// The path to a mirror of this package containing precompiled JS.
  ///
  /// This is used by the internal Google test runner so that test compilation
  /// can more effectively make use of Google's build tools.
  final String precompiledPath;

  /// The name of the reporter to use to display results.
  String get reporter => _reporter ?? defaultReporter;
  final String _reporter;

  /// The URL for the `pub serve` instance from which to load tests, or `null`
  /// if tests should be loaded from the filesystem.
  final Uri pubServeUrl;

  /// The default test timeout.
  ///
  /// When [merge]d, this combines with the other configuration's timeout using
  /// [Timeout.merge].
  final Timeout timeout;

  /// Whether to use command-line color escapes.
  bool get color => _color ?? canUseSpecialChars;
  final bool _color;

  /// How many tests to run concurrently.
  int get concurrency =>
      pauseAfterLoad ? 1 : (_concurrency ?? defaultConcurrency);
  final int _concurrency;

  /// The index of the current shard, if sharding is in use, or `null` if it's
  /// not.
  ///
  /// Sharding is a technique that allows the Google internal test framework to
  /// easily split a test run across multiple workers without requiring the
  /// tests to be modified by the user. When sharding is in use, the runner gets
  /// a shard index (this field) and a total number of shards, and is expected
  /// to provide the following guarantees:
  ///
  /// * Running the same invocation of the runner, with the same shard index and
  ///   total shards, will run the same set of tests.
  /// * Across all shards, each test must be run exactly once.
  ///
  /// In addition, tests should be balanced across shards as much as possible.
  final int shardIndex;

  /// The total number of shards, if sharding is in use, or `null` if it's not.
  ///
  /// See [shardIndex] for details.
  final int totalShards;

  /// The paths from which to load tests.
  List<String> get paths => _paths ?? ["test"];
  final List<String> _paths;

  /// Whether the load paths were passed explicitly or the default was used.
  bool get explicitPaths => _paths != null;

  /// The glob matching the basename of tests to run.
  ///
  /// This is used to find tests within a directory.
  Glob get filename => _filename ?? defaultFilename;
  final Glob _filename;

  /// The patterns to match against test names to decide which to run, or `null`
  /// if all tests should be run.
  ///
  /// All patterns must match in order for a test to be run.
  final Set<Pattern> patterns;

  /// The set of platforms on which to run tests.
  List<TestPlatform> get platforms => _platforms ?? [TestPlatform.vm];
  final List<TestPlatform> _platforms;

  /// The set of presets to use.
  ///
  /// Any chosen presets for the parent configuration are added to the chosen
  /// preset sets for child configurations as well.
  ///
  /// Note that the order of this set matters.
  final Set<String> chosenPresets;

  /// Only run tests whose tags match this selector.
  ///
  /// When [merge]d, this is intersected with the other configuration's included
  /// tags.
  final BooleanSelector includeTags;

  /// Do not run tests whose tags match this selector.
  ///
  /// When [merge]d, this is unioned with the other configuration's
  /// excluded tags.
  final BooleanSelector excludeTags;

  /// Configuration for particular tags.
  ///
  /// The keys are tag selectors, and the values are configurations for tests
  /// whose tags match those selectors. The configuration should only contain
  /// test-level configuration fields, but that isn't enforced.
  final Map<BooleanSelector, Configuration> tags;

  /// Tags that are added to the tests.
  ///
  /// This is usually only used for scoped configuration.
  final Set<String> addTags;

  /// The global test metadata derived from this configuration.
  Metadata get metadata => new Metadata(
      timeout: timeout,
      verboseTrace: verboseTrace,
      skip: skip,
      skipReason: skipReason,
      testOn: testOn,
      tags: addTags,
      forTag: mapMap(tags, value: (_, config) => config.metadata),
      onPlatform: mapMap(onPlatform, value: (_, config) => config.metadata));

  /// The set of tags that have been declared in any way in this configuration.
  Set<String> get knownTags {
    if (_knownTags != null) return _knownTags;

    var known = includeTags.variables.toSet()
      ..addAll(excludeTags.variables)
      ..addAll(addTags);

    for (var selector in tags.keys) {
      known.addAll(selector.variables);
    }

    for (var configuration in _children) {
      known.addAll(configuration.knownTags);
    }

    _knownTags = new UnmodifiableSetView(known);
    return _knownTags;
  }
  Set<String> _knownTags;

  /// Configuration for particular platforms.
  ///
  /// The keys are platform selectors, and the values are configurations for
  /// those platforms. These configuration should only contain test-level
  /// configuration fields, but that isn't enforced.
  final Map<PlatformSelector, Configuration> onPlatform;

  /// Configuration presets.
  ///
  /// These are configurations that can be explicitly selected by the user via
  /// the command line. Preset configuration takes precedence over the base
  /// configuration.
  ///
  /// This is guaranteed not to have any keys that match [chosenPresets]; those
  /// are resolved when the configuration is constructed.
  final Map<String, Configuration> presets;

  /// All preset names that are known to be valid.
  ///
  /// This includes presets that have already been resolved.
  Set<String> get knownPresets {
    if (_knownPresets != null) return _knownPresets;

    var known = presets.keys.toSet();
    for (var configuration in _children) {
      known.addAll(configuration.knownPresets);
    }

    _knownPresets = new UnmodifiableSetView(known);
    return _knownPresets;
  }
  Set<String> _knownPresets;

  /// All child configurations of [this] that may be selected under various
  /// circumstances.
  Iterable<Configuration> get _children sync* {
    yield* tags.values;
    yield* onPlatform.values;
    yield* presets.values;
  }

  /// Returns the current configuration, or a default configuration if no
  /// current configuration is set.
  ///
  /// The current configuration is set using [asCurrent].
  static Configuration get current =>
      Zone.current[_currentKey] ?? new Configuration();

  /// Parses the configuration from [args].
  ///
  /// Throws a [FormatException] if [args] are invalid.
  factory Configuration.parse(List<String> arguments) => args.parse(arguments);

  /// Loads the configuration from [path].
  ///
  /// If [global] is `true`, this restricts the configuration file to only rules
  /// that are supported globally.
  ///
  /// Throws an [IOException] if [path] does not exist or cannot be read. Throws
  /// a [FormatException] if its contents are invalid.
  factory Configuration.load(String path, {bool global: false}) =>
      load(path, global: global);

  factory Configuration({
      bool help,
      bool version,
      bool verboseTrace,
      bool jsTrace,
      bool skip,
      String skipReason,
      bool runSkipped,
      PlatformSelector testOn,
      bool pauseAfterLoad,
      bool color,
      String dart2jsPath,
      Iterable<String> dart2jsArgs,
      String precompiledPath,
      String reporter,
      int pubServePort,
      int concurrency,
      int shardIndex,
      int totalShards,
      Timeout timeout,
      Iterable<Pattern> patterns,
      Iterable<TestPlatform> platforms,
      Iterable<String> paths,
      Glob filename,
      Iterable<String> chosenPresets,
      BooleanSelector includeTags,
      BooleanSelector excludeTags,
      Iterable<String> addTags,
      Map<BooleanSelector, Configuration> tags,
      Map<PlatformSelector, Configuration> onPlatform,
      Map<String, Configuration> presets}) {
    _unresolved() => new Configuration._(
        help: help,
        version: version,
        verboseTrace: verboseTrace,
        jsTrace: jsTrace,
        skip: skip,
        skipReason: skipReason,
        runSkipped: runSkipped,
        testOn: testOn,
        pauseAfterLoad: pauseAfterLoad,
        color: color,
        dart2jsPath: dart2jsPath,
        dart2jsArgs: dart2jsArgs,
        precompiledPath: precompiledPath,
        reporter: reporter,
        pubServePort: pubServePort,
        concurrency: concurrency,
        shardIndex: shardIndex,
        totalShards: totalShards,
        timeout: timeout,
        patterns: patterns,
        platforms: platforms,
        paths: paths,
        filename: filename,
        chosenPresets: chosenPresets,
        includeTags: includeTags,
        excludeTags: excludeTags,
        addTags: addTags,

        // Make sure we pass [chosenPresets] to the child configurations as
        // well. This ensures that tags and platforms can have preset-specific
        // behavior.
        tags: _withChosenPresets(tags, chosenPresets),
        onPlatform: _withChosenPresets(onPlatform, chosenPresets),
        presets: _withChosenPresets(presets, chosenPresets));

    if (chosenPresets == null) return _unresolved();
    chosenPresets = new Set.from(chosenPresets);

    if (presets == null) return _unresolved();
    presets = new Map.from(presets);

    var knownPresets = presets.keys.toSet();

    var merged = chosenPresets.fold(Configuration.empty, (merged, preset) {
      if (!presets.containsKey(preset)) return merged;
      return merged.merge(presets.remove(preset));
    });

    var result = merged == Configuration.empty
        ? _unresolved()
        : _unresolved().merge(merged);

    // Make sure the configuration knows about presets that were selected and
    // thus removed from [presets].
    result._knownPresets = result.knownPresets.union(knownPresets);

    return result;
  }

  static Map<Object, Configuration> _withChosenPresets(
      Map<Object, Configuration> map, Set<String> chosenPresets) {
    if (map == null || chosenPresets == null) return map;
    return mapMap(map, value: (_, config) => config.change(
        chosenPresets: config.chosenPresets.union(chosenPresets)));
  }

  /// Creates new Configuration.
  ///
  /// Unlike [new Configuration], this assumes [presets] is already resolved.
  Configuration._({
          bool help,
          bool version,
          bool verboseTrace,
          bool jsTrace,
          bool skip,
          this.skipReason,
          bool runSkipped,
          PlatformSelector testOn,
          bool pauseAfterLoad,
          bool color,
          String dart2jsPath,
          Iterable<String> dart2jsArgs,
          this.precompiledPath,
          String reporter,
          int pubServePort,
          int concurrency,
          this.shardIndex,
          this.totalShards,
          Timeout timeout,
          Iterable<Pattern> patterns,
          Iterable<TestPlatform> platforms,
          Iterable<String> paths,
          Glob filename,
          Iterable<String> chosenPresets,
          BooleanSelector includeTags,
          BooleanSelector excludeTags,
          Iterable<String> addTags,
          Map<BooleanSelector, Configuration> tags,
          Map<PlatformSelector, Configuration> onPlatform,
          Map<String, Configuration> presets})
      : _help = help,
        _version = version,
        _verboseTrace = verboseTrace,
        _jsTrace = jsTrace,
        _skip = skip,
        _runSkipped = runSkipped,
        testOn = testOn ?? PlatformSelector.all,
        _pauseAfterLoad = pauseAfterLoad,
        _color = color,
        _dart2jsPath = dart2jsPath,
        dart2jsArgs = dart2jsArgs?.toList() ?? [],
        _reporter = reporter,
        pubServeUrl = pubServePort == null
            ? null
            : Uri.parse("http://localhost:$pubServePort"),
        _concurrency = concurrency,
        timeout = (pauseAfterLoad ?? false)
            ? Timeout.none
            : (timeout == null ? new Timeout.factor(1) : timeout),
        patterns = new UnmodifiableSetView(patterns?.toSet() ?? new Set()),
        _platforms = _list(platforms),
        _paths = _list(paths),
        _filename = filename,
        chosenPresets = new UnmodifiableSetView(
            chosenPresets?.toSet() ?? new Set()),
        includeTags = includeTags ?? BooleanSelector.all,
        excludeTags = excludeTags ?? BooleanSelector.none,
        addTags = new UnmodifiableSetView(addTags?.toSet() ?? new Set()),
        tags = _map(tags),
        onPlatform = _map(onPlatform),
        presets = _map(presets) {
    if (_filename != null && _filename.context.style != p.style) {
      throw new ArgumentError(
          "filename's context must match the current operating system, was "
              "${_filename.context.style}.");
    }

    if ((shardIndex == null) != (totalShards == null)) {
      throw new ArgumentError(
          "shardIndex and totalShards may only be passed together.");
    } else if (shardIndex != null) {
      RangeError.checkValueInInterval(
          shardIndex, 0, totalShards - 1, "shardIndex");
    }
  }

  /// Returns a [input] as an unmodifiable list or `null`.
  ///
  /// If [input] is `null` or empty, this returns `null`. Otherwise, it returns
  /// `input.toList()`.
  static List/*<T>*/ _list/*<T>*/(Iterable/*<T>*/ input) {
    if (input == null) return null;
    var list = new List/*<T>*/.unmodifiable(input);
    if (list.isEmpty) return null;
    return list;
  }

  /// Returns an unmodifiable copy of [input] or an empty unmodifiable map.
  static Map/*<K, V>*/ _map/*<K, V>*/(Map/*<K, V>*/ input) {
    if (input == null || input.isEmpty) return const {};
    return new Map.unmodifiable(input);
  }

  /// Runs [body] with [this] as [Configuration.current].
  ///
  /// This is zone-scoped, so [this] will be the current configuration in any
  /// asynchronous callbacks transitively created by [body].
  /*=T*/ asCurrent/*<T>*/(/*=T*/ body()) =>
      runZoned(body, zoneValues: {_currentKey: this});

  /// Merges this with [other].
  ///
  /// For most fields, if both configurations have values set, [other]'s value
  /// takes precedence. However, certain fields are merged together instead.
  /// This is indicated in those fields' documentation.
  Configuration merge(Configuration other) {
    if (this == Configuration.empty) return other;
    if (other == Configuration.empty) return this;

    var result = new Configuration(
        help: other._help ?? _help,
        version: other._version ?? _version,
        verboseTrace: other._verboseTrace ?? _verboseTrace,
        jsTrace: other._jsTrace ?? _jsTrace,
        skip: other._skip ?? _skip,
        skipReason: other.skipReason ?? skipReason,
        runSkipped: other._runSkipped ?? _runSkipped,
        testOn: testOn.intersection(other.testOn),
        pauseAfterLoad: other._pauseAfterLoad ?? _pauseAfterLoad,
        color: other._color ?? _color,
        dart2jsPath: other._dart2jsPath ?? _dart2jsPath,
        dart2jsArgs: dart2jsArgs.toList()..addAll(other.dart2jsArgs),
        precompiledPath: other.precompiledPath ?? precompiledPath,
        reporter: other._reporter ?? _reporter,
        pubServePort: (other.pubServeUrl ?? pubServeUrl)?.port,
        concurrency: other._concurrency ?? _concurrency,
        shardIndex: other.shardIndex ?? shardIndex,
        totalShards: other.totalShards ?? totalShards,
        timeout: timeout.merge(other.timeout),
        patterns: patterns.union(other.patterns),
        platforms: other._platforms ?? _platforms,
        paths: other._paths ?? _paths,
        filename: other._filename ?? _filename,
        chosenPresets: chosenPresets.union(other.chosenPresets),
        includeTags: includeTags.intersection(other.includeTags),
        excludeTags: excludeTags.union(other.excludeTags),
        addTags: other.addTags.union(addTags),
        tags: _mergeConfigMaps(tags, other.tags),
        onPlatform: _mergeConfigMaps(onPlatform, other.onPlatform),
        presets: _mergeConfigMaps(presets, other.presets));

    // Make sure the merged config preserves any presets that were chosen and
    // discarded.
    result._knownPresets = knownPresets.union(other.knownPresets);
    return result;
  }

  /// Returns a copy of this configuration with the given fields updated.
  ///
  /// Note that unlike [merge], this has no merging behavior—the old value is
  /// always replaced by the new one.
  Configuration change({
      bool help,
      bool version,
      bool verboseTrace,
      bool jsTrace,
      bool skip,
      String skipReason,
      bool runSkipped,
      PlatformSelector testOn,
      bool pauseAfterLoad,
      bool color,
      String dart2jsPath,
      Iterable<String> dart2jsArgs,
      String precompiledPath,
      String reporter,
      int pubServePort,
      int concurrency,
      int shardIndex,
      int totalShards,
      Timeout timeout,
      Iterable<Pattern> patterns,
      Iterable<TestPlatform> platforms,
      Iterable<String> paths,
      Glob filename,
      Iterable<String> chosenPresets,
      BooleanSelector includeTags,
      BooleanSelector excludeTags,
      Iterable<String> addTags,
      Map<BooleanSelector, Configuration> tags,
      Map<PlatformSelector, Configuration> onPlatform,
      Map<String, Configuration> presets}) {
    return new Configuration(
        help: help ?? _help,
        version: version ?? _version,
        verboseTrace: verboseTrace ?? _verboseTrace,
        jsTrace: jsTrace ?? _jsTrace,
        skip: skip ?? _skip,
        skipReason: skipReason ?? this.skipReason,
        runSkipped: runSkipped ?? _runSkipped,
        testOn: testOn ?? this.testOn,
        pauseAfterLoad: pauseAfterLoad ?? _pauseAfterLoad,
        color: color ?? _color,
        dart2jsPath: dart2jsPath ?? _dart2jsPath,
        dart2jsArgs: dart2jsArgs?.toList() ?? this.dart2jsArgs,
        precompiledPath: precompiledPath ?? this.precompiledPath,
        reporter: reporter ?? _reporter,
        pubServePort: pubServePort ?? pubServeUrl?.port,
        concurrency: concurrency ?? _concurrency,
        shardIndex: shardIndex ?? this.shardIndex,
        totalShards: totalShards ?? this.totalShards,
        timeout: timeout ?? this.timeout,
        patterns: patterns ?? this.patterns,
        platforms: platforms ?? _platforms,
        paths: paths ?? _paths,
        filename: filename ?? _filename,
        chosenPresets: chosenPresets ?? this.chosenPresets,
        includeTags: includeTags ?? this.includeTags,
        excludeTags: excludeTags ?? this.excludeTags,
        addTags: addTags ?? this.addTags,
        tags: tags ?? this.tags,
        onPlatform: onPlatform ?? this.onPlatform,
        presets: presets ?? this.presets);
  }

  /// Merges two maps whose values are [Configuration]s.
  ///
  /// Any overlapping keys in the maps have their configurations merged in the
  /// returned map.
  Map<Object, Configuration> _mergeConfigMaps(Map<Object, Configuration> map1,
          Map<Object, Configuration> map2) =>
      mergeMaps(map1, map2,
          value: (config1, config2) => config1.merge(config2));
}
