// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:boolean_selector/boolean_selector.dart';

import '../../backend/test_platform.dart';
import '../../frontend/timeout.dart';
import '../configuration.dart';
import 'values.dart';

/// The parser used to parse the command-line arguments.
final ArgParser _parser = (() {
  var parser = new ArgParser(allowTrailingOptions: true);

  var allPlatforms = TestPlatform.all.toList();
  if (!Platform.isMacOS) allPlatforms.remove(TestPlatform.safari);
  if (!Platform.isWindows) allPlatforms.remove(TestPlatform.internetExplorer);

  parser.addFlag("help", abbr: "h", negatable: false,
      help: "Shows this usage information.");
  parser.addFlag("version", negatable: false,
      help: "Shows the package's version.");
  parser.addOption("package-root", hide: true);

  // Note that defaultsTo declarations here are only for documentation purposes.
  // We pass null values rather than defaults to [new Configuration] so that it
  // merges properly with the config file.

  parser.addSeparator("======== Selecting Tests");
  parser.addOption("name",
      abbr: 'n',
      help: 'A substring of the name of the test to run.\n'
          'Regular expression syntax is supported.\n'
          'If passed multiple times, tests must match all substrings.',
      allowMultiple: true,
      splitCommas: false);
  parser.addOption("plain-name",
      abbr: 'N',
      help: 'A plain-text substring of the name of the test to run.\n'
          'If passed multiple times, tests must match all substrings.',
      allowMultiple: true,
      splitCommas: false);
  parser.addOption("tags",
      abbr: 't',
      help: 'Run only tests with all of the specified tags.\n'
          'Supports boolean selector syntax.',
      allowMultiple: true);
  parser.addOption("tag", hide: true, allowMultiple: true);
  parser.addOption("exclude-tags",
      abbr: 'x',
      help: "Don't run tests with any of the specified tags.\n"
          "Supports boolean selector syntax.",
      allowMultiple: true);
  parser.addOption("exclude-tag", hide: true, allowMultiple: true);

  parser.addSeparator("======== Running Tests");
  parser.addOption("platform",
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      defaultsTo: 'vm',
      allowed: allPlatforms.map((platform) => platform.identifier).toList(),
      allowMultiple: true);
  parser.addOption("preset",
      abbr: 'P',
      help: 'The configuration preset(s) to use.',
      allowMultiple: true);
  parser.addOption("concurrency",
      abbr: 'j',
      help: 'The number of concurrent test suites run.',
      defaultsTo: defaultConcurrency.toString(),
      valueHelp: 'threads');
  parser.addOption("pub-serve",
      help: 'The port of a pub serve instance serving "test/".',
      valueHelp: 'port');
  parser.addOption("timeout",
      help: 'The default test timeout. For example: 15s, 2x, none',
      defaultsTo: '30s');
  parser.addFlag("pause-after-load",
      help: 'Pauses for debugging before any tests execute.\n'
          'Implies --concurrency=1 and --timeout=none.\n'
          'Currently only supported for browser tests.',
      negatable: false);

  // These are used by the internal Google test runner, so they're hidden from
  // the --help output but still supported as stable API surface. See
  // [Configuration.shardIndex] for details on their semantics.
  parser.addOption("shard-index", hide: true);
  parser.addOption("total-shards", hide: true);

  parser.addSeparator("======== Output");
  parser.addOption("reporter",
      abbr: 'r',
      help: 'The runner used to print test results.',
      defaultsTo: defaultReporter,
      allowed: allReporters,
      allowedHelp: {
    'compact': 'A single line, updated continuously.',
    'expanded': 'A separate line for each update.',
    'json': 'A machine-readable format (see https://goo.gl/0HRhdZ).'
  });
  parser.addFlag("verbose-trace", negatable: false,
      help: 'Whether to emit stack traces with core library frames.');
  parser.addFlag("js-trace", negatable: false,
      help: 'Whether to emit raw JavaScript stack traces for browser tests.');
  parser.addFlag("color",
      help: 'Whether to use terminal colors.\n(auto-detected by default)');

  return parser;
})();

/// The usage string for the command-line arguments.
String get usage => _parser.usage;

/// Parses the configuration from [args].
///
/// Throws a [FormatException] if [args] are invalid.
Configuration parse(List<String> args) => new _Parser(args).parse();

/// A class for parsing an argument list.
///
/// This is used to provide access to the arg results across helper methods.
class _Parser {
  /// The parsed options.
  final ArgResults _options;

  _Parser(List<String> args) : _options = _parser.parse(args);

  /// Returns the parsed configuration.
  Configuration parse() {
    var patterns = (_options['name'] as List<String>)
        .map/*<Pattern>*/(
            (value) => _wrapFormatException('name', () => new RegExp(value)))
        .toList()
        ..addAll(_options['plain-name'] as List<String>);

    var includeTagSet = new Set.from(_options['tags'] ?? [])
      ..addAll(_options['tag'] ?? []);

    var includeTags = includeTagSet.fold(BooleanSelector.all, (selector, tag) {
      var tagSelector = new BooleanSelector.parse(tag);
      return selector.intersection(tagSelector);
    });

    var excludeTagSet = new Set.from(_options['exclude-tags'] ?? [])
      ..addAll(_options['exclude-tag'] ?? []);

    var excludeTags = excludeTagSet.fold(BooleanSelector.none, (selector, tag) {
      var tagSelector = new BooleanSelector.parse(tag);
      return selector.union(tagSelector);
    });

    var shardIndex = _parseOption('shard-index', int.parse);
    var totalShards = _parseOption('total-shards', int.parse);
    if ((shardIndex == null) != (totalShards == null)) {
      throw new FormatException(
          "--shard-index and --total-shards may only be passed together.");
    } else if (shardIndex != null) {
      if (shardIndex < 0) {
        throw new FormatException("--shard-index may not be negative.");
      } else if (shardIndex >= totalShards) {
        throw new FormatException(
            "--shard-index must be less than --total-shards.");
      }
    }

    return new Configuration(
        help: _ifParsed('help'),
        version: _ifParsed('version'),
        verboseTrace: _ifParsed('verbose-trace'),
        jsTrace: _ifParsed('js-trace'),
        pauseAfterLoad: _ifParsed('pause-after-load'),
        color: _ifParsed('color'),
        packageRoot: _ifParsed('package-root'),
        reporter: _ifParsed('reporter'),
        pubServePort: _parseOption('pub-serve', int.parse),
        concurrency: _parseOption('concurrency', int.parse),
        shardIndex: shardIndex,
        totalShards: totalShards,
        timeout: _parseOption('timeout', (value) => new Timeout.parse(value)),
        patterns: patterns,
        platforms: (_ifParsed('platform') as List<String>)
            ?.map(TestPlatform.find),
        chosenPresets: _ifParsed('preset') as List<String>,
        paths: _options.rest.isEmpty ? null : _options.rest,
        includeTags: includeTags,
        excludeTags: excludeTags);
  }

  /// Returns the parsed option for [name], or `null` if none was parsed.
  ///
  /// If the user hasn't explicitly chosen a value, we want to pass null values
  /// to [new Configuration] so that it considers those fields unset when
  /// merging with configuration from the config file.
  _ifParsed(String name) => _options.wasParsed(name) ? _options[name] : null;

  /// Runs [parse] on the value of the option [name], and wraps any
  /// [FormatException] it throws with additional information.
  /*=T*/ _parseOption/*<T>*/(String name, /*=T*/ parse(String value)) {
    if (!_options.wasParsed(name)) return null;

    var value = _options[name];
    if (value == null) return null;

    return _wrapFormatException(name, () => parse(value as String));
  }

  /// Runs [parse], and wraps any [FormatException] it throws with additional
  /// information.
  /*=T*/ _wrapFormatException/*<T>*/(String name, /*=T*/ parse()) {
    try {
      return parse();
    } on FormatException catch (error) {
      throw new FormatException('Couldn\'t parse --$name "${_options[name]}": '
          '${error.message}');
    }
  }
}
