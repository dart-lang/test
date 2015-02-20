// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.test.io;

import 'dart:io';
import 'dart:mirrors';

import 'package:path/path.dart' as p;

/// The root directory of the `unittest` package.
final String packageDir = _computePackageDir();
String _computePackageDir() =>
    p.dirname(p.dirname(_libraryPath(#unittest.test.io)));

/// Runs the unittest executable with the package root set properly.
ProcessResult runUnittest(List<String> args, {String workingDirectory,
    Map<String, String> environment}) {
  var allArgs = [
    p.join(packageDir, 'bin/unittest.dart'),
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

/// Returns the path to the library named [libraryName].
///
/// The library name must be globally unique, or the wrong library path may be
/// returned.
String _libraryPath(Symbol libraryName) {
  var lib = currentMirrorSystem().findLibrary(libraryName);
  return p.fromUri(lib.uri);
}


