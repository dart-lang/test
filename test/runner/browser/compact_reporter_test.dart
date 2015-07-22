// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import '../../io.dart';

void main() {
  useSandbox();

  test("prints the platform name when running on multiple platforms", () {
    d.file("test.dart", """
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""").create();

    var test = runTest([
      "-r", "compact",
      "-p", "content-shell",
      "-p", "vm",
      "-j", "1",
      "test.dart"
    ], compact: true);

    test.stdout.expect(containsInOrder(["[VM]", "[Dartium Content Shell]"]));

    test.shouldExit(0);
  });
}
