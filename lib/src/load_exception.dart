// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.load_exception;

import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'utils.dart';

class LoadException implements Exception {
  final String path;

  final innerError;

  LoadException(this.path, this.innerError);

  String toString() {
    var buffer = new StringBuffer('Failed to load "$path":');

    var innerString = getErrorMessage(innerError);
    if (innerError is IsolateSpawnException) {
      // If this is a parse error, get rid of the noisy preamble.
      innerString = innerString
          .replaceFirst("'${p.toUri(p.absolute(path))}': error: ", "");

      // If this is a file system error, get rid of both the preamble and the
      // useless stack trace.
      innerString = innerString.replaceFirst(
          "Unhandled exception:\n"
          "Uncaught Error: Load Error: FileSystemException: ",
          "");
      innerString = innerString.split("Stack Trace:\n").first.trim();
    }

    buffer.write(innerString.contains("\n") ? "\n" : " ");
    buffer.write(innerString);
    return buffer.toString();
  }
}
