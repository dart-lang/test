// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/io.dart';

import '../io.dart';

void main() {
  useSandbox();

  group("for suite", () {
    test("runs a test suite on a matching platform", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "vm");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't run a test suite on a non-matching platform", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "vm");

      var test = runTest(["--platform", "content-shell", "vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    }, tags: 'content-shell');

    test("runs a test suite on a matching operating system", () {
      _writeTestFile("os_test.dart", suiteTestOn: currentOS.name);

      var test = runTest(["os_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't run a test suite on a non-matching operating system", () {
      _writeTestFile("os_test.dart", suiteTestOn: _otherOS,
          loadable: false);

      var test = runTest(["os_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });

    test("only loads matching files when loading as a group", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "vm");
      _writeTestFile("browser_test.dart",
          suiteTestOn: "browser", loadable: false);
      _writeTestFile("this_os_test.dart", suiteTestOn: currentOS.name);
      _writeTestFile("other_os_test.dart",
          suiteTestOn: _otherOS, loadable: false);

      var test = runTest(["."]);
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    });
  });

  group("for group", () {
    test("runs a VM group on the VM", () {
      _writeTestFile("vm_test.dart", groupTestOn: "vm");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't run a Browser group on the VM", () {
      _writeTestFile("browser_test.dart", groupTestOn: "browser");

      var test = runTest(["browser_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });

    test("runs a browser group on a browser", () {
      _writeTestFile("browser_test.dart", groupTestOn: "browser");

      var test = runTest(
          ["--platform", "content-shell", "browser_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    }, tags: 'content-shell');

    test("doesn't run a VM group on a browser", () {
      _writeTestFile("vm_test.dart", groupTestOn: "vm");

      var test = runTest(["--platform", "content-shell", "vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    }, tags: 'content-shell');
  });

  group("for test", () {
    test("runs a VM test on the VM", () {
      _writeTestFile("vm_test.dart", testTestOn: "vm");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't run a browser test on the VM", () {
      _writeTestFile("browser_test.dart", testTestOn: "browser");

      var test = runTest(["browser_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });

    test("runs a browser test on a browser", () {
      _writeTestFile("browser_test.dart", testTestOn: "browser");

      var test = runTest(
          ["--platform", "content-shell", "browser_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    }, tags: 'content-shell');

    test("doesn't run a VM test on a browser", () {
      _writeTestFile("vm_test.dart", testTestOn: "vm");

      var test = runTest(["--platform", "content-shell", "vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    }, tags: 'content-shell');
  });

  group("with suite, group, and test selectors", () {
    test("runs the test if all selectors match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "!browser",
          groupTestOn: "!js", testTestOn: "vm");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't runs the test if the suite doesn't match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "browser",
          groupTestOn: "!js", testTestOn: "vm");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });

    test("doesn't runs the test if the group doesn't match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "!browser",
          groupTestOn: "browser", testTestOn: "vm");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });

    test("doesn't runs the test if the test doesn't match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "!browser",
          groupTestOn: "!js", testTestOn: "browser");

      var test = runTest(["vm_test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });
  });
}

/// Writes a test file with some platform selectors to [filename].
///
/// Each of [suiteTestOn], [groupTestOn], and [testTestOn] is a platform
/// selector that's suite-, group-, and test-level respectively. If [loadable]
/// is `false`, the test file will be made unloadable on the Dart VM.
void _writeTestFile(String filename, {String suiteTestOn, String groupTestOn,
    String testTestOn, bool loadable: true}) {
  var buffer = new StringBuffer();
  if (suiteTestOn != null) buffer.writeln("@TestOn('$suiteTestOn')");
  if (!loadable) buffer.writeln("import 'dart:html';");

  buffer
      ..writeln("import 'package:test/test.dart';")
      ..writeln("void main() {")
      ..writeln("  group('group', () {");

  if (testTestOn != null) {
    buffer.writeln("    test('test', () {}, testOn: '$testTestOn');");
  } else {
    buffer.writeln("    test('test', () {});");
  }

  if (groupTestOn != null) {
    buffer.writeln("  }, testOn: '$groupTestOn');");
  } else {
    buffer.writeln("  });");
  }

  buffer.writeln("}");

  d.file(filename, buffer.toString()).create();
}
