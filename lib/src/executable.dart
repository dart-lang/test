// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): This is under lib so that it can be used by the unittest dummy
// package. Once that package is no longer being updated, move this back into
// bin.
library test.executable;

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:yaml/yaml.dart';

import 'backend/metadata.dart';
import 'runner/application_exception.dart';
import 'runner/configuration.dart';
import 'runner/engine.dart';
import 'runner/load_exception.dart';
import 'runner/load_suite.dart';
import 'runner/loader.dart';
import 'runner/reporter/compact.dart';
import 'runner/reporter/expanded.dart';
import 'util/exit_codes.dart' as exit_codes;
import 'utils.dart';

/// A merged stream of all signals that tell the test runner to shut down
/// gracefully.
///
/// Signals will only be captured as long as this has an active subscription.
/// Otherwise, they'll be handled by Dart's default signal handler, which
/// terminates the program immediately.
final _signals = Platform.isWindows
    ? ProcessSignal.SIGINT.watch()
    : mergeStreams([
        ProcessSignal.SIGTERM.watch(),
        ProcessSignal.SIGINT.watch()
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

Configuration _configuration;

main(List<String> args) async {
  try {
    _configuration = new Configuration.parse(args);
  } on FormatException catch (error) {
    _printUsage(error.message);
    exitCode = exit_codes.usage;
    return;
  }

  if (_configuration.help) {
    _printUsage();
    return;
  }

  if (_configuration.version) {
    if (!_printVersion()) {
      stderr.writeln("Couldn't find version number.");
      exitCode = exit_codes.data;
    }
    return;
  }

  if (_configuration.pubServeUrl != null && !_usesTransformer) {
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

  if (!_configuration.explicitPaths &&
      !new Directory(_configuration.paths.single).existsSync()) {
    _printUsage('No test files were passed and the default "test/" '
        "directory doesn't exist.");
    exitCode = exit_codes.data;
    return;
  }

  var metadata = new Metadata(
      verboseTrace: _configuration.verboseTrace);
  var loader = new Loader(_configuration.platforms,
      pubServeUrl: _configuration.pubServeUrl,
      packageRoot: _configuration.packageRoot,
      color: _configuration.color,
      metadata: metadata,
      jsTrace: _configuration.jsTrace);

  var closed = false;
  var signalSubscription;
  signalSubscription = _signals.listen((_) {
    closed = true;
    signalSubscription.cancel();
    loader.close();
  });

  try {
    var engine = new Engine(concurrency: _configuration.concurrency);

    var watch = _configuration.reporter == "compact"
        ? CompactReporter.watch
        : ExpandedReporter.watch;

    watch(
        engine,
        color: _configuration.color,
        verboseTrace: _configuration.verboseTrace,
        printPath: _configuration.paths.length > 1 ||
            new Directory(_configuration.paths.single).existsSync(),
        printPlatform: _configuration.platforms.length > 1);

    // Override the signal handler to close [reporter]. [loader] will still be
    // closed in the [whenComplete] below.
    signalSubscription.onData((_) async {
      closed = true;
      signalSubscription.cancel();

      // Wait a bit to print this message, since printing it eagerly looks weird
      // if the tests then finish immediately.
      var timer = new Timer(new Duration(seconds: 1), () {
        // Print a blank line first to ensure that this doesn't interfere with
        // the compact reporter's unfinished line.
        print("");
        print("Waiting for current test(s) to finish.");
        print("Press Control-C again to terminate immediately.");
      });

      // Make sure we close the engine *before* the loader. Otherwise,
      // LoadSuites provided by the loader may get into bad states.
      await engine.close();
      timer.cancel();
      await loader.close();
    });

    try {
      var results = await Future.wait([
        _loadSuites(loader, engine),
        engine.run()
      ], eagerError: true);

      if (closed) return;

      // Explicitly check "== true" here because [engine.run] can return `null`
      // if the engine was closed prematurely.
      exitCode = results.last == true ? 0 : 1;
    } finally {
      signalSubscription.cancel();
      await engine.close();
    }

    if (engine.passed.length == 0 && engine.failed.length == 0 &&
        engine.skipped.length == 0 && _configuration.pattern != null) {
      stderr.write('No tests match ');

      if (_configuration.pattern is RegExp) {
        var pattern = (_configuration.pattern as RegExp).pattern;
        stderr.writeln('regular expression "$pattern".');
      } else {
        stderr.writeln('"${_configuration.pattern}".');
      }
      exitCode = exit_codes.data;
    }
  } on ApplicationException catch (error) {
    stderr.writeln(error.message);
    exitCode = exit_codes.data;
  } catch (error, stackTrace) {
    stderr.writeln(getErrorMessage(error));
    stderr.writeln(new Trace.from(stackTrace).terse);
    stderr.writeln(
        "This is an unexpected error. Please file an issue at "
            "http://github.com/dart-lang/test\n"
        "with the stack trace and instructions for reproducing the error.");
    exitCode = exit_codes.software;
  } finally {
    signalSubscription.cancel();
    await loader.close();
  }
}

/// Load the test suites in [_configuration.paths] that match
/// [_configuration.pattern] and pass them to [engine].
///
/// This completes once all the tests have been added to the engine. It does not
/// run the engine.
Future _loadSuites(Loader loader, Engine engine) async {
  var group = new FutureGroup();

  mergeStreams(_configuration.paths.map((path) {
    if (new Directory(path).existsSync()) return loader.loadDir(path);
    if (new File(path).existsSync()) return loader.loadFile(path);

    return new Stream.fromIterable([
      new LoadSuite("loading $path", () =>
          throw new LoadException(path, 'Does not exist.'))
    ]);
  })).listen((loadSuite) {
    group.add(new Future.sync(() {
      engine.suiteSink.add(loadSuite.changeSuite((suite) {
        if (_configuration.pattern == null) return suite;
        return suite.change(tests: suite.tests.where(
            (test) => test.name.contains(_configuration.pattern)));
      }));
    }));
  }, onError: (error, stackTrace) {
    group.add(new Future.error(error, stackTrace));
  }, onDone: group.close);

  await group.future;

  // Once we've loaded all the suites, notify the engine that no more will be
  // coming.
  engine.suiteSink.close();
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

${Configuration.usage}
""");
}

/// Prints the version number of the test package.
///
/// This loads the version number from the current package's lockfile. It
/// returns true if it successfully printed the version number and false if it
/// couldn't be loaded.
bool _printVersion() {
  var lockfile;
  try {
    lockfile = loadYaml(new File("pubspec.lock").readAsStringSync());
  } on FormatException catch (_) {
    return false;
  } on IOException catch (_) {
    return false;
  }

  if (lockfile is! Map) return false;
  var packages = lockfile["packages"];
  if (packages is! Map) return false;
  var package = packages["test"];
  if (package is! Map) return false;

  var source = package["source"];
  if (source is! String) return false;

  switch (source) {
    case "hosted":
      var version = package["version"];
      if (version is! String) return false;

      print(version);
      return true;

    case "git":
      var version = package["version"];
      if (version is! String) return false;
      var description = package["description"];
      if (description is! Map) return false;
      var ref = description["resolved-ref"];
      if (ref is! String) return false;

      print("$version (${ref.substring(0, 7)})");
      return true;

    case "path":
      var version = package["version"];
      if (version is! String) return false;
      var description = package["description"];
      if (description is! Map) return false;
      var path = description["path"];
      if (path is! String) return false;

      print("$version (from $path)");
      return true;

    default: return false;
  }
}
