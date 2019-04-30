// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test("accessing the getter creates the directory", () {
    expect(Directory(d.sandbox).existsSync(), isTrue);
  });

  test("the directory is deleted after the test", () {
    String sandbox;
    addTearDown(() {
      expect(Directory(sandbox).existsSync(), isFalse);
    });

    sandbox = d.sandbox;
  });

  test("path() returns a path in the sandbox", () {
    expect(d.path("foo"), equals(p.join(d.sandbox, "foo")));
  });
}
