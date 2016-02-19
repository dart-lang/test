// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:boolean_selector/boolean_selector.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../backend/metadata.dart';
import '../backend/test_platform.dart';
import '../frontend/timeout.dart';
import '../util/io.dart';
import '../utils.dart';
import 'configuration/args.dart' as args;
import 'configuration/load.dart';
import 'configuration/values.dart';

/// A class that encapsulates the command-line configuration of the test runner.
class Configuration {
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

  /// Whether to pause for debugging after loading each test suite.
  bool get pauseAfterLoad => _pauseAfterLoad ?? false;
  final bool _pauseAfterLoad;

  /// The package root for resolving "package:" URLs.
  String get packageRoot => _packageRoot ?? p.join(p.current, 'packages');
  final String _packageRoot;

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

  /// The pattern to match against test names to decide which to run, or `null`
  /// if all tests should be run.
  final Pattern pattern;

  /// The set of platforms on which to run tests.
  List<TestPlatform> get platforms => _platforms ?? [TestPlatform.vm];
  final List<TestPlatform> _platforms;

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
      tags: addTags,
      forTag: mapMap(tags, value: (_, config) => config.metadata));

  /// The set of tags that have been declaredin any way in this configuration.
  Set<String> get knownTags {
    if (_knownTags != null) return _knownTags;

    var known = includeTags.variables.toSet()
      ..addAll(excludeTags.variables)
      ..addAll(addTags);
    tags.forEach((selector, config) {
      known.addAll(selector.variables);
      known.addAll(config.knownTags);
    });

    _knownTags = new UnmodifiableSetView(known);
    return _knownTags;
  }
  Set<String> _knownTags;

  /// Parses the configuration from [args].
  ///
  /// Throws a [FormatException] if [args] are invalid.
  factory Configuration.parse(List<String> arguments) => args.parse(arguments);

  /// Loads the configuration from [path].
  ///
  /// Throws an [IOException] if [path] does not exist or cannot be read. Throws
  /// a [FormatException] if its contents are invalid.
  factory Configuration.load(String path) => load(path);

  Configuration({bool help, bool version, bool verboseTrace, bool jsTrace,
          bool pauseAfterLoad, bool color, String packageRoot, String reporter,
          int pubServePort, int concurrency, Timeout timeout, this.pattern,
          Iterable<TestPlatform> platforms, Iterable<String> paths,
          Glob filename, BooleanSelector includeTags,
          BooleanSelector excludeTags, Iterable addTags,
          Map<BooleanSelector, Configuration> tags})
      : _help = help,
        _version = version,
        _verboseTrace = verboseTrace,
        _jsTrace = jsTrace,
        _pauseAfterLoad = pauseAfterLoad,
        _color = color,
        _packageRoot = packageRoot,
        _reporter = reporter,
        pubServeUrl = pubServePort == null
            ? null
            : Uri.parse("http://localhost:$pubServePort"),
        _concurrency = concurrency,
        timeout = (pauseAfterLoad ?? false)
            ? Timeout.none
            : (timeout == null ? new Timeout.factor(1) : timeout),
        _platforms = _list(platforms),
        _paths = _list(paths),
        _filename = filename,
        includeTags = includeTags ?? BooleanSelector.all,
        excludeTags = excludeTags ?? BooleanSelector.none,
        addTags = addTags?.toSet() ?? new Set(),
        tags = tags == null ? const {} : new Map.unmodifiable(tags) {
    if (_filename != null && _filename.context.style != p.style) {
      throw new ArgumentError(
          "filename's context must match the current operating system, was "
              "${_filename.context.style}.");
    }
  }

  /// Returns a [input] as a list or `null`.
  ///
  /// If [input] is `null` or empty, this returns `null`. Otherwise, it returns
  /// `input.toList()`.
  static List _list(Iterable input) {
    if (input == null) return null;
    input = input.toList();
    if (input.isEmpty) return null;
    return input;
  }

  /// Merges this with [other].
  ///
  /// For most fields, if both configurations have values set, [other]'s value
  /// takes precedence. However, certain fields are merged together instead.
  /// This is indicated in those fields' documentation.
  Configuration merge(Configuration other) {
    return new Configuration(
        help: other._help ?? _help,
        version: other._version ?? _version,
        verboseTrace: other._verboseTrace ?? _verboseTrace,
        jsTrace: other._jsTrace ?? _jsTrace,
        pauseAfterLoad: other._pauseAfterLoad ?? _pauseAfterLoad,
        color: other._color ?? _color,
        packageRoot: other._packageRoot ?? _packageRoot,
        reporter: other._reporter ?? _reporter,
        pubServePort: (other.pubServeUrl ?? pubServeUrl)?.port,
        concurrency: other._concurrency ?? _concurrency,
        timeout: timeout.merge(other.timeout),
        pattern: other.pattern ?? pattern,
        platforms: other._platforms ?? _platforms,
        paths: other._paths ?? _paths,
        filename: other._filename ?? _filename,
        includeTags: includeTags.intersection(other.includeTags),
        excludeTags: excludeTags.union(other.excludeTags),
        addTags: other.addTags.union(addTags),
        tags: mergeMaps(tags, other.tags,
            value: (config1, config2) => config1.merge(config2)));
  }
}
