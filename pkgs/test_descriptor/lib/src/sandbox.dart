// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

/// The sandbox directory in which descriptors are created and validated by
/// default.
///
/// This is a temporary directory beneath [Directory.systemTemp]. A new one is
/// created the first time [sandbox] is accessed for each test case, and
/// automatically deleted after the test finishes running.
String get sandbox {
  if (_sandbox != null) return _sandbox;
  // Resolve symlinks so we don't end up with inconsistent paths on Mac OS where
  // /tmp is symlinked.
  _sandbox = Directory.systemTemp
      .createTempSync('dart_test_')
      .resolveSymbolicLinksSync();

  addTearDown(() async {
    var sandbox = _sandbox;
    _sandbox = null;
    await new Directory(sandbox).delete(recursive: true);
  });

  return _sandbox;
}

String _sandbox;

/// Whether [sandbox] has been created.
bool get sandboxExists => _sandbox != null;
