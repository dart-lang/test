// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.test.io;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';
import 'package:unittest/unittest.dart';

/// The root directory of the `unittest` package.
final String packageDir = _computePackageDir();
String _computePackageDir() {
  var trace = new Trace.current();
  return p.dirname(p.dirname(p.fromUri(trace.frames.first.uri)));
}

/// Returns a matcher that matches a [FileSystemException] with the given
/// [message].
Matcher isFileSystemException(String message) => predicate(
    (error) => error is FileSystemException && error.message == message,
    'is a FileSystemException with message "$message"');

