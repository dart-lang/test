// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.test.io;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/io.dart';

/// The path to the root directory of the `test` package.
final String packageDir = p.dirname(p.dirname(libraryPath(#test.test.io)));

/// Runs the test executable with the package root set properly.
ProcessResult runUnittest(List<String> args, {String workingDirectory,
    Map<String, String> environment}) {
  var allArgs = [
    p.absolute(p.join(packageDir, 'bin/test.dart')),
    "--package-root=${p.join(packageDir, 'packages')}"
  ]..addAll(args);

  if (environment == null) environment = {};
  environment.putIfAbsent("_UNITTEST_USE_COLOR", () => "false");

  // TODO(nweiz): Use ScheduledProcess once it's compatible.
  return runDart(allArgs, workingDirectory: workingDirectory,
      environment: environment);
}

/// Runs Dart.
ProcessResult runDart(List<String> args, {String workingDirectory,
    Map<String, String> environment}) {
  var allArgs = Platform.executableArguments.toList()..addAll(args);

  // TODO(nweiz): Use ScheduledProcess once it's compatible.
  return Process.runSync(Platform.executable, allArgs,
      workingDirectory: workingDirectory, environment: environment);
}

/// Starts the test executable with the package root set properly.
Future<Process> startUnittest(List<String> args, {String workingDirectory,
    Map<String, String> environment}) {
  var allArgs = [
    p.absolute(p.join(packageDir, 'bin/test.dart')),
    "--package-root=${p.join(packageDir, 'packages')}"
  ]..addAll(args);

  if (environment == null) environment = {};
  environment.putIfAbsent("_UNITTEST_USE_COLOR", () => "false");

  return startDart(allArgs, workingDirectory: workingDirectory,
      environment: environment);
}

/// Starts Dart.
Future<Process> startDart(List<String> args, {String workingDirectory,
    Map<String, String> environment}) {
  var allArgs = Platform.executableArguments.toList()..addAll(args);

  // TODO(nweiz): Use ScheduledProcess once it's compatible.
  return Process.start(Platform.executable, allArgs,
      workingDirectory: workingDirectory, environment: environment);
}
