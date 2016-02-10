// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';

import '../../frontend/timeout.dart';
import '../../backend/test_platform.dart';
import '../../utils.dart';
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
          'Regular expression syntax is supported.');
  parser.addOption("plain-name",
      abbr: 'N',
      help: 'A plain-text substring of the name of the test to run.');
  // TODO(nweiz): Support the full platform-selector syntax for choosing which
  // tags to run. In the shorter term, disallow non-"identifier" tags.
  parser.addOption("tags",
      abbr: 't',
      help: 'Run only tests with all of the specified tags.',
      allowMultiple: true);
  parser.addOption("tag", hide: true, allowMultiple: true);
  parser.addOption("exclude-tags",
      abbr: 'x',
      help: "Don't run tests with any of the specified tags.",
      allowMultiple: true);
  parser.addOption("exclude-tag", hide: true, allowMultiple: true);

  parser.addSeparator("======== Running Tests");
  parser.addOption("platform",
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      defaultsTo: 'vm',
      allowed: allPlatforms.map((platform) => platform.identifier).toList(),
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
Configuration parse(List<String> args) {
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

  var tags = new Set();
  tags.addAll(options['tags'] ?? []);
  tags.addAll(options['tag'] ?? []);

  var excludeTags = new Set();
  excludeTags.addAll(options['exclude-tags'] ?? []);
  excludeTags.addAll(options['exclude-tag'] ?? []);

  var tagIntersection = tags.intersection(excludeTags);
  if (tagIntersection.isNotEmpty) {
    throw new FormatException(
        'The ${pluralize('tag', tagIntersection.length)} '
        '${toSentence(tagIntersection)} '
        '${pluralize('was', tagIntersection.length, plural: 'were')} '
        'both included and excluded.');
  }

  // If the user hasn't explicitly chosen a value, we want to pass null values
  // to [new Configuration] so that it considers those fields unset when merging
  // with configuration from the config file.
  ifParsed(name) => options.wasParsed(name) ? options[name] : null;

  return new Configuration(
      help: ifParsed('help'),
      version: ifParsed('version'),
      verboseTrace: ifParsed('verbose-trace'),
      jsTrace: ifParsed('js-trace'),
      pauseAfterLoad: ifParsed('pause-after-load'),
      color: ifParsed('color'),
      packageRoot: ifParsed('package-root'),
      reporter: ifParsed('reporter'),
      pubServePort: _wrapFormatException(options, 'pub-serve', int.parse),
      concurrency: _wrapFormatException(options, 'concurrency', int.parse),
      timeout: _wrapFormatException(options, 'timeout',
          (value) => new Timeout.parse(value)),
      pattern: pattern,
      platforms: ifParsed('platform')?.map(TestPlatform.find),
      paths: options.rest.isEmpty ? null : options.rest,
      tags: tags,
      excludeTags: excludeTags);
}

/// Runs [parse] on the value of the option [name], and wraps any
/// [FormatException] it throws with additional information.
_wrapFormatException(ArgResults options, String name, parse(value)) {
  if (!options.wasParsed(name)) return null;

  var value = options[name];
  if (value == null) return null;

  try {
    return parse(value);
  } on FormatException catch (error) {
    throw new FormatException('Couldn\'t parse --$name "${options[name]}": '
        '${error.message}');
  }
}
