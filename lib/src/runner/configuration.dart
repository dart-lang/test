// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.configuration;

import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../frontend/timeout.dart';
import '../backend/metadata.dart';
import '../backend/test_platform.dart';
import '../util/io.dart';

/// The default number of test suites to run at once.
///
/// This defaults to half the available processors, since presumably some of
/// them will be used for the OS and other processes.
final _defaultConcurrency = math.max(1, Platform.numberOfProcessors ~/ 2);

/// A class that encapsulates the command-line configuration of the test runner.
class Configuration {
  /// The parser used to parse the command-line arguments.
  static final ArgParser _parser = (() {
    var parser = new ArgParser(allowTrailingOptions: true);

    var allPlatforms = TestPlatform.all.toList();
    if (!Platform.isMacOS) allPlatforms.remove(TestPlatform.safari);
    if (!Platform.isWindows) allPlatforms.remove(TestPlatform.internetExplorer);

    parser.addFlag("help", abbr: "h", negatable: false,
        help: "Shows this usage information.");
    parser.addFlag("version", negatable: false,
        help: "Shows the package's version.");
    parser.addOption("package-root", hide: true);
    parser.addOption("name",
        abbr: 'n',
        help: 'A substring of the name of the test to run.\n'
            'Regular expression syntax is supported.');
    parser.addOption("plain-name",
        abbr: 'N',
        help: 'A plain-text substring of the name of the test to run.');
    parser.addOption("platform",
        abbr: 'p',
        help: 'The platform(s) on which to run the tests.',
        allowed: allPlatforms.map((platform) => platform.identifier).toList(),
        defaultsTo: 'vm',
        allowMultiple: true);
    parser.addOption("concurrency",
        abbr: 'j',
        help: 'The number of concurrent test suites run.\n'
            '(defaults to $_defaultConcurrency)',
        valueHelp: 'threads');
    parser.addOption("pub-serve",
        help: 'The port of a pub serve instance serving "test/".',
        valueHelp: 'port');
    parser.addFlag("pause-after-load",
        help: 'Pauses for debugging before any tests execute.\n'
            'Implies --concurrency=1.\n'
            'Currently only supported for browser tests.',
        negatable: false);
    parser.addOption("reporter",
        abbr: 'r',
        help: 'The runner used to print test results.',
        allowed: ['compact', 'expanded'],
        defaultsTo: Platform.isWindows ? 'expanded' : 'compact',
        allowedHelp: {
      'compact': 'A single line, updated continuously.',
      'expanded': 'A separate line for each update.'
    });
    parser.addFlag("verbose-trace", negatable: false,
        help: 'Whether to emit stack traces with core library frames.');
    parser.addFlag("js-trace", negatable: false,
        help: 'Whether to emit raw JavaScript stack traces for browser tests.');
    parser.addFlag("color", defaultsTo: null,
        help: 'Whether to use terminal colors.\n(auto-detected by default)');
    parser.addOption("tags",
      help: 'Comma-separated list of tags to run',
      allowMultiple: true,
      splitCommas: true);

    return parser;
  })();

  /// The usage string for the command-line arguments.
  static String get usage => _parser.usage;

  /// Whether `--help` was passed.
  final bool help;

  /// Whether `--version` was passed.
  final bool version;

  /// Whether stack traces should be presented as-is or folded to remove
  /// irrelevant packages.
  final bool verboseTrace;

  /// Whether JavaScript stack traces should be left as-is or converted to
  /// Dart-like traces.
  final bool jsTrace;

  /// Whether to pause for debugging after loading each test suite.
  final bool pauseAfterLoad;

  /// The package root for resolving "package:" URLs.
  final String packageRoot;

  /// The name of the reporter to use to display results.
  final String reporter;

  /// The URL for the `pub serve` instance from which to load tests, or `null`
  /// if tests should be loaded from the filesystem.
  final Uri pubServeUrl;

  /// Whether to use command-line color escapes.
  final bool color;

  /// How many tests to run concurrently.
  final int concurrency;

  /// The from which to load tests.
  final List<String> paths;

  /// Whether the load paths were passed explicitly or the default was used.
  final bool explicitPaths;

  /// The pattern to match against test names to decide which to run, or `null`
  /// if all tests should be run.
  final Pattern pattern;

  /// The set of platforms on which to run tests.
  final List<TestPlatform> platforms;

  /// Restricts the set of tests to a set of tags
  final List<String> tags;

  /// The global test metadata derived from this configuration.
  Metadata get metadata =>
      new Metadata(
          timeout: pauseAfterLoad ? Timeout.none : null,
          verboseTrace: verboseTrace);

  /// Parses the configuration from [args].
  ///
  /// Throws a [FormatException] if [args] are invalid.
  factory Configuration.parse(List<String> args) {
    var options = _parser.parse(args);

    var pattern;
    if (options['name'] != null) {
      if (options["plain-name"] != null) {
        throw new FormatException(
            "--name and --plain-name may not both be passed.");
      }

      pattern = _wrapFormatException(
          options, 'name', (value) => new RegExp(value));
    } else if (options['plain-name'] != null) {
      pattern = options['plain-name'];
    }

    return new Configuration(
        help: options['help'],
        version: options['version'],
        verboseTrace: options['verbose-trace'],
        jsTrace: options['js-trace'],
        pauseAfterLoad: options['pause-after-load'],
        color: options['color'],
        packageRoot: options['package-root'],
        reporter: options['reporter'],
        pubServePort: _wrapFormatException(options, 'pub-serve', int.parse),
        concurrency: _wrapFormatException(options, 'concurrency', int.parse,
            orElse: () => _defaultConcurrency),
        pattern: pattern,
        platforms: options['platform'].map(TestPlatform.find),
        paths: options.rest.isEmpty ? null : options.rest,
        tags: options['tags']);
  }

  /// Runs [parse] on the value of the option [name], and wraps any
  /// [FormatException] it throws with additional information.
  static _wrapFormatException(ArgResults options, String name, parse(value),
      {orElse()}) {
    var value = options[name];
    if (value == null) return orElse == null ? null : orElse();

    try {
      return parse(value);
    } on FormatException catch (error) {
      throw new FormatException('Couldn\'t parse --$name "${options[name]}": '
          '${error.message}');
    }
  }

  Configuration({this.help: false, this.version: false,
          this.verboseTrace: false, this.jsTrace: false,
          bool pauseAfterLoad: false, bool color, String packageRoot,
          String reporter, int pubServePort, int concurrency, this.pattern,
          Iterable<TestPlatform> platforms, Iterable<String> paths,
          List<String> tags})
      : pauseAfterLoad = pauseAfterLoad,
        color = color == null ? canUseSpecialChars : color,
        packageRoot = packageRoot == null
            ? p.join(p.current, 'packages')
            : packageRoot,
        reporter = reporter == null ? 'compact' : reporter,
        pubServeUrl = pubServePort == null
            ? null
            : Uri.parse("http://localhost:$pubServePort"),
        concurrency = pauseAfterLoad
            ? 1
            : (concurrency == null ? _defaultConcurrency : concurrency),
        platforms = platforms == null ? [TestPlatform.vm] : platforms.toList(),
        paths = paths == null ? ["test"] : paths.toList(),
        explicitPaths = paths != null,
        this.tags = tags == null
            ? const <String>[]
            : tags;
}
