// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.configuration;

import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

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
        hide: !supportsPubServe,
        valueHelp: 'port');
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

    return parser;
  })();

  /// The usage string for the command-line arguments.
  static String get usage => _parser.usage;

  /// The results of parsing the arguments.
  final ArgResults _options;

  /// Whether `--help` was passed.
  bool get help => _options['help'];

  /// Whether `--version` was passed.
  bool get version => _options['version'];

  /// Whether stack traces should be presented as-is or folded to remove
  /// irrelevant packages.
  bool get verboseTrace => _options['verbose-trace'];

  /// Whether JavaScript stack traces should be left as-is or converted to
  /// Dart-like traces.
  bool get jsTrace => _options['js-trace'];

  /// The package root for resolving "package:" URLs.
  String get packageRoot => _options['package-root'] == null
      ? p.join(p.current, 'packages')
      : _options['package-root'];

  /// The name of the reporter to use to display results.
  String get reporter => _options['reporter'];

  /// The URL for the `pub serve` instance from which to load tests, or `null`
  /// if tests should be loaded from the filesystem.
  Uri get pubServeUrl {
    if (_options['pub-serve'] == null) return null;
    return Uri.parse("http://localhost:${_options['pub-serve']}");
  }

  /// Whether to use command-line color escapes.
  bool get color =>
      _options["color"] == null ? canUseSpecialChars : _options["color"];

  /// How many tests to run concurrently.
  int get concurrency => _concurrency;
  int _concurrency;

  /// The from which to load tests.
  List<String> get paths => _options.rest.isEmpty ? ["test"] : _options.rest;

  /// Whether the load paths were passed explicitly or the default was used.
  bool get explicitPaths => _options.rest.isNotEmpty;

  /// The pattern to match against test names to decide which to run, or `null`
  /// if all tests should be run.
  Pattern get pattern {
    if (_options["name"] != null) {
      return new RegExp(_options["name"]);
    } else if (_options["plain-name"] != null) {
      return _options["plain-name"];
    } else {
      return null;
    }
  }

  /// The set of platforms on which to run tests.
  List<TestPlatform> get platforms =>
      _options["platform"].map(TestPlatform.find).toList();

  /// Parses the configuration from [args].
  ///
  /// Throws a [FormatException] if [args] are invalid.
  Configuration.parse(List<String> args)
      : _options = _parser.parse(args) {
    _concurrency = _options['concurrency'] == null
        ? _defaultConcurrency
        : _wrapFormatException('concurrency', int.parse);

    if (_options["name"] != null && _options["plain-name"] != null) {
      throw new FormatException(
          "--name and --plain-name may not both be passed.");
    }
  }

  /// Runs [parse] on the value of the option [name], and wraps any
  /// [FormatException] it throws with additional information.
  _wrapFormatException(String name, parse(value)) {
    try {
      return parse(_options[name]);
    } on FormatException catch (error) {
      throw new FormatException('Couldn\'t parse --$name "${_options[name]}": '
          '${error.message}');
    }
  }
}
