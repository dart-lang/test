// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.unittest;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:unittest/src/backend/test_platform.dart';
import 'package:unittest/src/runner/reporter/compact.dart';
import 'package:unittest/src/runner/load_exception.dart';
import 'package:unittest/src/runner/loader.dart';
import 'package:unittest/src/util/exit_codes.dart' as exit_codes;
import 'package:unittest/src/util/io.dart';
import 'package:unittest/src/utils.dart';

/// The argument parser used to parse the executable arguments.
final _parser = new ArgParser(allowTrailingOptions: true);

void main(List<String> args) {
  _parser.addFlag("help", abbr: "h", negatable: false,
      help: "Shows this usage information.");
  _parser.addOption("package-root", hide: true);
  _parser.addOption("platform",
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      allowed: TestPlatform.all.map((platform) => platform.identifier).toList(),
      defaultsTo: 'vm',
      allowMultiple: true);
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

  var platforms = options["platform"].map(TestPlatform.find);
  var loader = new Loader(platforms,
      packageRoot: options["package-root"], color: color);
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
    var reporter = new CompactReporter(flatten(suites), color: color);
    return reporter.run().then((success) {
      exitCode = success ? 0 : 1;
    }).whenComplete(() => reporter.close());
  }).catchError((error, stackTrace) {
    if (error is LoadException) {
      // TODO(nweiz): color this message?
      stderr.writeln(getErrorMessage(error));

      // Only print stack traces for load errors that come from the user's 
      if (error.innerError is! IOException &&
          error.innerError is! IsolateSpawnException &&
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
              "http://github.com/dart-lang/unittest\n"
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

Usage: pub run unittest:unittest [files or directories...]

${_parser.usage}
""");
}
