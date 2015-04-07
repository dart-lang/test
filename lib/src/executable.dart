// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): This is under lib so that it can be used by the unittest dummy
// package. Once that package is no longer being updated, move this back into
// bin.
library test.executable;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:yaml/yaml.dart';

import 'backend/test_platform.dart';
import 'runner/reporter/compact.dart';
import 'runner/load_exception.dart';
import 'runner/loader.dart';
import 'util/exit_codes.dart' as exit_codes;
import 'util/io.dart';
import 'utils.dart';

/// The argument parser used to parse the executable arguments.
final _parser = new ArgParser(allowTrailingOptions: true);

/// The default number of test suites to run at once.
///
/// This defaults to half the available processors, since presumably some of
/// them will be used for the OS and other processes.
final _defaultConcurrency = math.max(1, Platform.numberOfProcessors ~/ 2);

/// A merged stream of all signals that tell the test runner to shut down
/// gracefully.
///
/// Signals will only be captured as long as this has an active subscription.
/// Otherwise, they'll be handled by Dart's default signal handler, which
/// terminates the program immediately.
final _signals = mergeStreams([
  ProcessSignal.SIGTERM.watch(), ProcessSignal.SIGINT.watch()
]);

/// Returns whether the current package has a pubspec which uses the
/// `test/pub_serve` transformer.
bool get _usesTransformer {
  if (!new File('pubspec.yaml').existsSync()) return false;
  var contents = new File('pubspec.yaml').readAsStringSync();

  var yaml;
  try {
    yaml = loadYaml(contents);
  } on FormatException {
    return false;
  }

  if (yaml is! Map) return false;

  var transformers = yaml['transformers'];
  if (transformers == null) return false;
  if (transformers is! List) return false;

  return transformers.any((transformer) {
    if (transformer is String) return transformer == 'test/pub_serve';
    if (transformer is! Map) return false;
    if (transformer.keys.length != 1) return false;
    return transformer.keys.single == 'test/pub_serve';
  });
}

void main(List<String> args) {
  _parser.addFlag("help", abbr: "h", negatable: false,
      help: "Shows this usage information.");
  _parser.addOption("package-root", hide: true);
  _parser.addOption("name",
      abbr: 'n',
      help: 'A substring of the name of the test to run.\n'
          'Regular expression syntax is supported.');
  _parser.addOption("plain-name",
      abbr: 'N',
      help: 'A plain-text substring of the name of the test to run.');
  _parser.addOption("platform",
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      allowed: TestPlatform.all.map((platform) => platform.identifier).toList(),
      defaultsTo: 'vm',
      allowMultiple: true);
  _parser.addOption("concurrency",
      abbr: 'j',
      help: 'The number of concurrent test suites run.\n'
          '(defaults to $_defaultConcurrency)',
      valueHelp: 'threads');
  _parser.addOption("pub-serve",
      help: 'The port of a pub serve instance serving "test/".',
      hide: !supportsPubServe,
      valueHelp: 'port');
  _parser.addFlag("color", defaultsTo: null,
      help: 'Whether to use terminal colors.\n(auto-detected by default)');

  var options;
  try {
    options = _parser.parse(args);
  } on FormatException catch (error) {
    _printUsage(error.message);
    exitCode = exit_codes.usage;
    return;
  }

  if (options["help"]) {
    _printUsage();
    return;
  }

  var color = options["color"];
  if (color == null) color = canUseSpecialChars;

  var pubServeUrl;
  if (options["pub-serve"] != null) {
    pubServeUrl = Uri.parse("http://localhost:${options['pub-serve']}");
    if (!_usesTransformer) {
      stderr.write('''
When using --pub-serve, you must include the "test/pub_serve" transformer in
your pubspec:

transformers:
- test/pub_serve:
    \$include: test/**_test.dart
''');
      exitCode = exit_codes.data;
      return;
    }
  }

  var platforms = options["platform"].map(TestPlatform.find);
  var loader = new Loader(platforms,
      pubServeUrl: pubServeUrl,
      packageRoot: options["package-root"],
      color: color);

  var concurrency = _defaultConcurrency;
  if (options["concurrency"] != null) {
    try {
      concurrency = int.parse(options["concurrency"]);
    } catch (error) {
      _printUsage('Couldn\'t parse --concurrency "${options["concurrency"]}":'
          ' ${error.message}');
      exitCode = exit_codes.usage;
      return;
    }
  }

  var signalSubscription;
  var closed = false;
  signalSubscription = _signals.listen((_) {
    signalSubscription.cancel();
    closed = true;
    loader.close();
  });

  new Future.sync(() {
    var paths = options.rest;
    if (paths.isEmpty) {
      if (!new Directory("test").existsSync()) {
        throw new LoadException("test",
            "No test files were passed and the default directory doesn't "
                "exist.");
      }
      paths = ["test"];
    }

    return Future.wait(paths.map((path) {
      if (new Directory(path).existsSync()) return loader.loadDir(path);
      if (new File(path).existsSync()) return loader.loadFile(path);
      throw new LoadException(path, 'Does not exist.');
    }));
  }).then((suites) {
    if (closed) return null;
    suites = flatten(suites);

    var pattern;
    if (options["name"] != null) {
      if (options["plain-name"] != null) {
        _printUsage("--name and --plain-name may not both be passed.");
        exitCode = exit_codes.data;
        return null;
      }
      pattern = new RegExp(options["name"]);
    } else if (options["plain-name"] != null) {
      pattern = options["plain-name"];
    }

    if (pattern != null) {
      suites = suites.map((suite) {
        return suite.change(
            tests: suite.tests.where((test) => test.name.contains(pattern)));
      }).toList();

      if (suites.every((suite) => suite.tests.isEmpty)) {
        stderr.write('No tests match ');

        if (pattern is RegExp) {
          stderr.write('regular expression "${pattern.pattern}".');
        } else {
          stderr.writeln('"$pattern".');
        }
        exitCode = exit_codes.data;
        return null;
      }
    }

    var reporter = new CompactReporter(flatten(suites),
        concurrency: concurrency, color: color);

    // Override the signal handler to close [reporter]. [loader] will still be
    // closed in the [whenComplete] below.
    signalSubscription.onData((_) {
      signalSubscription.cancel();
      closed = true;

      // Wait a bit to print this message, since printing it eagerly looks weird
      // if the tests then finish immediately.
      var timer = new Timer(new Duration(seconds: 1), () {
        // Print a blank line first to ensure that this doesn't interfere with
        // the compact reporter's unfinished line.
        print("");
        print("Waiting for current test(s) to finish.");
        print("Press Control-C again to terminate immediately.");
      });

      reporter.close().then((_) => timer.cancel());
    });

    return reporter.run().then((success) {
      exitCode = success ? 0 : 1;
    }).whenComplete(() {
      signalSubscription.cancel();
      return reporter.close();
    });
  }).whenComplete(signalSubscription.cancel).catchError((error, stackTrace) {
    if (error is LoadException) {
      stderr.writeln(error.toString(color: color));

      // Only print stack traces for load errors that come from the user's 
      if (error.innerError is! IOException &&
          error.innerError is! IsolateSpawnException &&
          error.innerError is! FormatException &&
          error.innerError is! String) {
        stderr.write(terseChain(stackTrace));
      }

      exitCode = error.innerError is IOException
          ? exit_codes.io
          : exit_codes.data;
    } else {
      stderr.writeln(getErrorMessage(error));
      stderr.writeln(new Trace.from(stackTrace).terse);
      stderr.writeln(
          "This is an unexpected error. Please file an issue at "
              "http://github.com/dart-lang/test\n"
          "with the stack trace and instructions for reproducing the error.");
      exitCode = exit_codes.software;
    }
  }).whenComplete(() {
    return loader.close().then((_) {
      // If we're on a Dart version that doesn't support Isolate.kill(), we have
      // to manually exit so that dangling isolates don't prevent it.
      if (!supportsIsolateKill) exit(exitCode);
    });
  });
}

/// Print usage information for this command.
///
/// If [error] is passed, it's used in place of the usage message and the whole
/// thing is printed to stderr instead of stdout.
void _printUsage([String error]) {
  var output = stdout;

  var message = "Runs tests in this package.";
  if (error != null) {
    message = error;
    output = stderr;
  }

  output.write("""$message

Usage: pub run test:test [files or directories...]

${_parser.usage}
""");
}
