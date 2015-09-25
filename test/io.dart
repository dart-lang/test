// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.test.io;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/io.dart';

/// The path to the root directory of the `test` package.
final String packageDir = p.dirname(p.dirname(libraryPath(#test.test.io)));

/// The path to the `pub` executable in the current Dart SDK.
final _pubPath = p.absolute(p.join(
    p.dirname(Platform.resolvedExecutable),
    Platform.isWindows ? 'pub.bat' : 'pub'));

/// The platform-specific message emitted when a nonexistent file is loaded.
final String noSuchFileMessage = Platform.isWindows
    ? "The system cannot find the file specified."
    : "No such file or directory";

/// A regular expression that matches the output of "pub serve".
final _servingRegExp =
    new RegExp(r'^Serving myapp [a-z]+ on http://localhost:(\d+)$');

/// A future that will return the port of a pub serve instance run via
/// [runPubServe].
///
/// This should only be called after [runPubServe].
Future<int> get pubServePort => _pubServePortCompleter.future;
Completer<int> _pubServePortCompleter;

/// The path to the sandbox directory.
///
/// This is only set in tests for which [useSandbox] is active.
String get sandbox => _sandbox;
String _sandbox;

/// Declares a [setUp] function that creates a sandbox diretory and sets it as
/// the default for scheduled_test's directory descriptors.
///
/// This should be called outside of any tests. If [additionalSetup] is passed,
/// it's run after the sandbox creation has been scheduled.
void useSandbox([void additionalSetup()]) {
  setUp(() {
    _sandbox = createTempDir();
    d.defaultRoot = _sandbox;

    currentSchedule.onComplete.schedule(() {
      try {
        new Directory(_sandbox).deleteSync(recursive: true);
      } on IOException catch (_) {
        // Silently swallow exceptions on Windows. If the test failed, there may
        // still be lingering processes that have files in the sandbox open,
        // which will cause this to fail on Windows.
        if (!Platform.isWindows) rethrow;
      }
    }, 'deleting the sandbox directory');

    if (additionalSetup != null) additionalSetup();
  });
}

/// Expects that the entire stdout stream of [test] equals [expected].
void expectStdoutEquals(ScheduledProcess test, String expected) =>
    _expectStreamEquals(test.stdoutStream(), expected);

/// Expects that the entire stderr stream of [test] equals [expected].
void expectStderrEquals(ScheduledProcess test, String expected) =>
    _expectStreamEquals(test.stderrStream(), expected);

/// Expects that the entirety of the line stream [stream] equals [expected].
void _expectStreamEquals(Stream<String> stream, String expected) {
  expect((() async {
    var lines = await stream.toList();
    expect(lines.join("\n").trim(), equals(expected.trim()));
  })(), completes);
}

/// Returns a [StreamMatcher] that asserts that the stream emits strings
/// containing each string in [strings] in order.
///
/// This expects each string in [strings] to match a different string in the
/// stream.
StreamMatcher containsInOrder(Iterable<String> strings) =>
    inOrder(strings.map((string) => consumeThrough(contains(string))));

/// Runs the test executable with the package root set properly.
ScheduledProcess runTest(List args, {bool compact: false,
    int concurrency, Map<String, String> environment, bool failFast: false}) {
  if (concurrency == null) concurrency = 1;

  var allArgs = [
    p.absolute(p.join(packageDir, 'bin/test.dart')),
    "--package-root=${p.join(packageDir, 'packages')}",
    "--concurrency=$concurrency"
  ];

  if (!compact) allArgs.addAll(["-r", "expanded"]);
  if (failFast) allArgs.addAll(["-f"]);
  allArgs.addAll(args);

  if (environment == null) environment = {};
  environment.putIfAbsent("_UNITTEST_USE_COLOR", () => "false");

  return runDart(allArgs,
      environment: environment,
      description: "dart bin/test.dart");
}

/// Runs Dart.
ScheduledProcess runDart(List args, {Map<String, String> environment,
    String description}) {
  var allArgs = Platform.executableArguments.map((arg) {
    // The package root might be relative, so we need to make it absolute if
    // we're going to run in a different working directory.
    if (!arg.startsWith("--package-root=")) return arg;
    return "--package-root=" +
        p.absolute(p.fromUri(arg.substring("--package-root=".length)));
  }).toList()..addAll(args);

  return new ScheduledProcess.start(
      p.absolute(Platform.resolvedExecutable), allArgs,
      workingDirectory: _sandbox,
      environment: environment,
      description: description);
}

/// Runs Pub.
ScheduledProcess runPub(List args, {Map<String, String> environment}) {
  return new ScheduledProcess.start(
      _pubPath, args,
      workingDirectory: _sandbox,
      environment: environment,
      description: "pub ${args.first}");
}

/// Runs "pub serve".
///
/// This returns assigns [_pubServePort] to a future that will complete to the
/// port of the "pub serve" instance.
ScheduledProcess runPubServe({List args, String workingDirectory,
    Map<String, String> environment}) {
  _pubServePortCompleter = new Completer();
  currentSchedule.onComplete.schedule(() => _pubServePortCompleter = null);

  var allArgs = ['serve', '--port', '0'];
  if (args != null) allArgs.addAll(args);

  var pub = runPub(allArgs, environment: environment);

  schedule(() async {
    var match;
    while (match == null) {
      var line = await pub.stdout.next();
      match = _servingRegExp.firstMatch(line);
    }
    _pubServePortCompleter.complete(int.parse(match[1]));
  }, "waiting for pub serve to emit its port number");

  return pub;
}
