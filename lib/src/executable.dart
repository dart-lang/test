// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): This is under lib so that it can be used by the unittest dummy
// package. Once that package is no longer being updated, move this back into
// bin.
library test.executable;

import 'dart:io';

import 'package:stack_trace/stack_trace.dart';
import 'package:yaml/yaml.dart';

import 'runner.dart';
import 'runner/application_exception.dart';
import 'runner/configuration.dart';
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

main(List<String> args) async {
  var configuration;
  try {
    configuration = new Configuration.parse(args);
  } on FormatException catch (error) {
    _printUsage(error.message);
    exitCode = exit_codes.usage;
    return;
  }

  if (configuration.help) {
    _printUsage();
    return;
  }

  if (configuration.version) {
    if (!_printVersion()) {
      stderr.writeln("Couldn't find version number.");
      exitCode = exit_codes.data;
    }
    return;
  }

  if (configuration.pubServeUrl != null && !_usesTransformer) {
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

  if (!configuration.explicitPaths &&
      !new Directory(configuration.paths.single).existsSync()) {
    _printUsage('No test files were passed and the default "test/" '
        "directory doesn't exist.");
    exitCode = exit_codes.data;
    return;
  }

  var runner = new Runner(configuration);

  var signalSubscription;
  close() async {
    if (signalSubscription == null) return;
    signalSubscription.cancel();
    signalSubscription = null;
    await runner.close();
  }

  signalSubscription = _signals.listen((_) => close());

  try {
    exitCode = (await runner.run()) ? 0 : 1;
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
    await close();
  }
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
