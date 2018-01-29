// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math' as math;

import 'package:glob/glob.dart';

/// The default number of test suites to run at once.
///
/// This defaults to half the available processors, since presumably some of
/// them will be used for the OS and other processes.
final defaultConcurrency = math.max(1, Platform.numberOfProcessors ~/ 2);

/// The default filename pattern.
///
/// This is stored here so that we don't have to recompile it multiple times.
final defaultFilename = new Glob("*_test.dart");

/// The default line length for output.
final int defaultLineLength = () {
  try {
    return stdout.terminalColumns;
  } on UnsupportedError {
    // This can throw an [UnsupportedError] if we're running in a JS context
    // where `dart:io` is unavaiable.
    return 200;
  } on StdoutException {
    return 200;
  }
}();
