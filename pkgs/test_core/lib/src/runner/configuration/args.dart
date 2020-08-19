// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:boolean_selector/boolean_selector.dart';
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/frontend/timeout.dart'; // ignore: implementation_imports

import '../../util/io.dart';
import '../configuration.dart';
import '../runtime_selection.dart';
import 'reporters.dart';
import 'values.dart';

/// The parser used to parse the command-line arguments.
final ArgParser _parser = (() {
  var parser = ArgParser(allowTrailingOptions: true);

  var allRuntimes = Runtime.builtIn.toList()..remove(Runtime.vm);
  if (!Platform.isMacOS) allRuntimes.remove(Runtime.safari);
  if (!Platform.isWindows) allRuntimes.remove(Runtime.internetExplorer);

  parser.addFlag('help',
      abbr: 'h', negatable: false, help: 'Shows this usage information.');
  parser.addFlag('version',
      negatable: false, help: "Shows the package's version.");

  // Note that defaultsTo declarations here are only for documentation purposes.
  // We pass null instead of the default so that it merges properly with the
  // config file.

  parser.addSeparator('======== Selecting Tests');
  parser.addMultiOption('name',
      abbr: 'n',
      help: 'A substring of the name of the test to run.\n'
          'Regular expression syntax is supported.\n'
          'If passed multiple times, tests must match all substrings.',
      splitCommas: false);
  parser.addMultiOption('plain-name',
      abbr: 'N',
      help: 'A plain-text substring of the name of the test to run.\n'
          'If passed multiple times, tests must match all substrings.',
      splitCommas: false);
  parser.addMultiOption('tags',
      abbr: 't',
      help: 'Run only tests with all of the specified tags.\n'
          'Supports boolean selector syntax.');
  parser.addMultiOption('tag', hide: true);
  parser.addMultiOption('exclude-tags',
      abbr: 'x',
      help: "Don't run tests with any of the specified tags.\n"
          'Supports boolean selector syntax.');
  parser.addMultiOption('exclude-tag', hide: true);
  parser.addFlag('run-skipped',
      help: 'Run skipped tests instead of skipping them.');

  parser.addSeparator('======== Running Tests');

  // The UI term "platform" corresponds with the implementation term "runtime".
  // The [Runtime] class used to be called [TestPlatform], but it was changed to
  // avoid conflicting with [SuitePlatform]. We decided not to also change the
  // UI to avoid a painful migration.
  parser.addMultiOption('platform',
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.\n'
          '[vm (default), '
          '${allRuntimes.map((runtime) => runtime.identifier).join(", ")}]');
  parser.addMultiOption('preset',
      abbr: 'P', help: 'The configuration preset(s) to use.');
  parser.addOption('concurrency',
      abbr: 'j',
      help: 'The number of concurrent test suites run.',
      defaultsTo: defaultConcurrency.toString(),
      valueHelp: 'threads');
  parser.addOption('total-shards',
      help: 'The total number of invocations of the test runner being run.');
  parser.addOption('shard-index',
      help: 'The index of this test runner invocation (of --total-shards).');
  parser.addOption('pub-serve',
      help: 'The port of a pub serve instance serving "test/".',
      valueHelp: 'port');
  parser.addOption('timeout',
      help: 'The default test timeout. For example: 15s, 2x, none',
      defaultsTo: '30s');
  parser.addFlag('pause-after-load',
      help: 'Pauses for debugging before any tests execute.\n'
          'Implies --concurrency=1, --debug, and --timeout=none.\n'
          'Currently only supported for browser tests.',
      negatable: false);
  parser.addFlag('debug',
      help: 'Runs the VM and Chrome tests in debug mode.', negatable: false);
  parser.addOption('coverage',
      help: 'Gathers coverage and outputs it to the specified directory.\n'
          'Implies --debug.',
      valueHelp: 'directory');
  parser.addFlag('chain-stack-traces',
      help: 'Chained stack traces to provide greater exception details\n'
          'especially for asynchronous code. It may be useful to disable\n'
          'to provide improved test performance but at the cost of\n'
          'debuggability.',
      defaultsTo: true);
  parser.addFlag('no-retry',
      help: "Don't re-run tests that have retry set.",
      defaultsTo: false,
      negatable: false);
  parser.addOption('test-randomize-ordering-seed',
      help: 'The seed to randomize the execution order of test cases.\n'
          'Must be a 32bit unsigned integer or "random".\n'
          'If "random", pick a random seed to use.\n'
          'If not passed, do not randomize test case execution order.');

  var reporterDescriptions = <String, String>{};
  for (var reporter in allReporters.keys) {
    reporterDescriptions[reporter] = allReporters[reporter]!.description;
  }

  parser.addSeparator('======== Output');
  parser.addOption('reporter',
      abbr: 'r',
      help: 'The runner used to print test results.',
      defaultsTo: defaultReporter,
      allowed: reporterDescriptions.keys.toList(),
      allowedHelp: reporterDescriptions);
  parser.addOption('file-reporter',
      help: 'The reporter used to write test results to a file.\n'
          'Should be in the form <reporter>:<filepath>, '
          'e.g. "json:reports/tests.json"');
  parser.addFlag('verbose-trace',
      negatable: false,
      help: 'Whether to emit stack traces with core library frames.');
  parser.addFlag('js-trace',
      negatable: false,
      help: 'Whether to emit raw JavaScript stack traces for browser tests.');
  parser.addFlag('color',
      help: 'Whether to use terminal colors.\n(auto-detected by default)');

  /// The following options are used only by the internal Google test runner.
  /// They're hidden and not supported as stable API surface outside Google.

  parser.addOption('configuration',
      help: 'The path to the configuration file.', hide: true);
  parser.addOption('dart2js-path',
      help: 'The path to the dart2js executable.', hide: true);
  parser.addMultiOption('dart2js-args',
      help: 'Extra arguments to pass to dart2js.', hide: true);

  // If we're running test/dir/my_test.dart, we'll look for
  // test/dir/my_test.dart.html in the precompiled directory.
  parser.addOption('precompiled',
      help: 'The path to a mirror of the package directory containing HTML '
          'that points to precompiled JS.',
      hide: true);

  return parser;
})();

/// The usage string for the command-line arguments.
String get usage => _parser.usage;

/// Parses the configuration from [args].
///
/// Throws a [FormatException] if [args] are invalid.
Configuration parse(List<String> args) => _Parser(args).parse();

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
        .map<Pattern>(
            (value) => _wrapFormatException('name', () => RegExp(value)))
        .toList()
          ..addAll(_options['plain-name'] as List<String>);

    var includeTagSet = Set.from(_options['tags'] as Iterable? ?? [])
      ..addAll(_options['tag'] as Iterable? ?? []);

    var includeTags = includeTagSet.fold(BooleanSelector.all,
        (BooleanSelector selector, tag) {
      var tagSelector = BooleanSelector.parse(tag as String);
      return selector.intersection(tagSelector);
    });

    var excludeTagSet = Set.from(_options['exclude-tags'] as Iterable? ?? [])
      ..addAll(_options['exclude-tag'] as Iterable? ?? []);

    var excludeTags = excludeTagSet.fold(BooleanSelector.none,
        (BooleanSelector selector, tag) {
      var tagSelector = BooleanSelector.parse(tag as String);
      return selector.union(tagSelector);
    });

    var shardIndex = _parseOption('shard-index', int.parse);
    var totalShards = _parseOption('total-shards', int.parse);
    if ((shardIndex == null) != (totalShards == null)) {
      throw FormatException(
          '--shard-index and --total-shards may only be passed together.');
    } else if (shardIndex != null) {
      if (shardIndex < 0) {
        throw FormatException('--shard-index may not be negative.');
      } else if (shardIndex >= totalShards!) {
        throw FormatException(
            '--shard-index must be less than --total-shards.');
      }
    }

    var testRandomizeOrderingSeed =
        _parseOption('test-randomize-ordering-seed', (value) {
      var seed = value == 'random'
          ? Random().nextInt(4294967295)
          : int.parse(value).toUnsigned(32);
      print('Shuffling test order with --test-randomize-ordering-seed=$seed');

      return seed;
    });

    var color = _ifParsed<bool>('color') ?? canUseSpecialChars;

    var platform = _ifParsed<List<String>>('platform')
        ?.map((runtime) => RuntimeSelection(runtime))
        .toList();
    if (platform
            ?.any((runtime) => runtime.name == Runtime.phantomJS.identifier) ??
        false) {
      var yellow = color ? '\u001b[33m' : '';
      var noColor = color ? '\u001b[0m' : '';
      print('${yellow}Warning:$noColor '
          'PhatomJS is deprecated and will be removed in version ^2.0.0');
    }

    return Configuration(
        help: _ifParsed('help'),
        version: _ifParsed('version'),
        verboseTrace: _ifParsed('verbose-trace'),
        chainStackTraces: _ifParsed('chain-stack-traces'),
        jsTrace: _ifParsed('js-trace'),
        pauseAfterLoad: _ifParsed('pause-after-load'),
        debug: _ifParsed('debug'),
        color: color,
        configurationPath: _ifParsed('configuration'),
        dart2jsPath: _ifParsed('dart2js-path'),
        dart2jsArgs: _ifParsed('dart2js-args'),
        precompiledPath: _ifParsed('precompiled'),
        reporter: _ifParsed('reporter'),
        fileReporters: _parseFileReporterOption(),
        coverage: _ifParsed('coverage'),
        pubServePort: _parseOption('pub-serve', int.parse),
        concurrency: _parseOption('concurrency', int.parse),
        shardIndex: shardIndex,
        totalShards: totalShards,
        timeout: _parseOption('timeout', (value) => Timeout.parse(value)),
        patterns: patterns,
        runtimes: platform,
        runSkipped: _ifParsed('run-skipped'),
        chosenPresets: _ifParsed('preset'),
        paths: _options.rest.isEmpty ? null : _options.rest,
        includeTags: includeTags,
        excludeTags: excludeTags,
        noRetry: _ifParsed('no-retry'),
        testRandomizeOrderingSeed: testRandomizeOrderingSeed);
  }

  /// Returns the parsed option for [name], or `null` if none was parsed.
  ///
  /// If the user hasn't explicitly chosen a value, we want to pass null values
  /// to [new Configuration] so that it considers those fields unset when
  /// merging with configuration from the config file.
  T? _ifParsed<T>(String name) =>
      _options.wasParsed(name) ? _options[name] as T : null;

  /// Runs [parse] on the value of the option [name], and wraps any
  /// [FormatException] it throws with additional information.
  T? _parseOption<T>(String name, T Function(String) parse) {
    if (!_options.wasParsed(name)) return null;

    var value = _options[name];
    if (value == null) return null;

    return _wrapFormatException(name, () => parse(value as String));
  }

  Map<String, String>? _parseFileReporterOption() =>
      _parseOption('file-reporter', (value) {
        if (!value.contains(':')) {
          throw FormatException(
              'option must be in the form <reporter>:<filepath>, e.g. '
              '"json:reports/tests.json"');
        }
        final sep = value.indexOf(':');
        final reporter = value.substring(0, sep);
        if (!allReporters.containsKey(reporter)) {
          throw FormatException('"$reporter" is not a supported reporter');
        }
        return {reporter: value.substring(sep + 1)};
      });

  /// Runs [parse], and wraps any [FormatException] it throws with additional
  /// information.
  T _wrapFormatException<T>(String name, T Function() parse) {
    try {
      return parse();
    } on FormatException catch (error) {
      throw FormatException('Couldn\'t parse --$name "${_options[name]}": '
          '${error.message}');
    }
  }
}
