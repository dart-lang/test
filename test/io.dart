// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.test.io;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

/// The root directory of the `unittest` package.
final String packageDir = _computePackageDir();
String _computePackageDir() {
  var trace = new Trace.current();
  return p.dirname(p.dirname(p.fromUri(trace.frames.first.uri)));
}

/// Runs the unittest executable with the package root set properly.
ProcessResult runUnittest(List<String> args, {String workingDirectory}) {
  var allArgs = Platform.executableArguments.toList()
     ..add(p.join(packageDir, 'bin/unittest.dart'))
     ..add("--package-root=${p.join(packageDir, 'packages')}")
     ..addAll(args);

  // TODO(nweiz): Use ScheduledProcess once it's compatible.
  return Process.runSync(Platform.executable, allArgs,
      workingDirectory: workingDirectory);
}
