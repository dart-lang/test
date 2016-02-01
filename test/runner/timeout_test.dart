// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

void main() {
  useSandbox();

  test("respects top-level @Timeout declarations", () {
    d.file("test.dart", '''
@Timeout(const Duration(seconds: 0))

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("timeout", () async {
    await new Future.delayed(Duration.ZERO);
  });
}
''').create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "Test timed out after 0 seconds.",
      "-1: Some tests failed."
    ]));
    test.shouldExit(1);
  });

  test("respects the --timeout flag", () {
    d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("timeout", () async {
    await new Future.delayed(Duration.ZERO);
  });
}
''').create();

    var test = runTest(["--timeout=0s", "test.dart"]);
    test.stdout.expect(containsInOrder([
      "Test timed out after 0 seconds.",
      "-1: Some tests failed."
    ]));
    test.shouldExit(1);
  });

  test("the --timeout flag applies on top of the default 30s timeout", () {
    d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("no timeout", () async {
    await new Future.delayed(new Duration(milliseconds: 250));
  });

  test("timeout", () async {
    await new Future.delayed(new Duration(milliseconds: 750));
  });
}
''').create();

    // This should make the timeout about 500ms, which should cause exactly one
    // test to fail.
    var test = runTest(["--timeout=0.016x", "test.dart"]);
    test.stdout.expect(containsInOrder([
      "Test timed out after 0.4 seconds.",
      "-1: Some tests failed."
    ]));
    test.shouldExit(1);
  });
}

