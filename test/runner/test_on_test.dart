// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../io.dart';

String _sandbox;

final _otherOS = Platform.isWindows ? "mac-os" : "windows";

void main() {
  setUp(() {
    _sandbox = createTempDir();
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  group("for suite", () {
    test("runs a test suite on a matching platform", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "vm");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't run a test suite on a non-matching platform", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "vm");

      var result = _runUnittest(["--platform", "chrome", "vm_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });

    test("runs a test suite on a matching operating system", () {
      _writeTestFile("os_test.dart", suiteTestOn: currentOS.name);

      var result = _runUnittest(["os_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't run a test suite on a non-matching operating system", () {
      _writeTestFile("os_test.dart", suiteTestOn: _otherOS,
          loadable: false);

      var result = _runUnittest(["os_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });

    test("only loads matching files when loading as a group", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "vm");
      _writeTestFile("chrome_test.dart",
          suiteTestOn: "chrome", loadable: false);
      _writeTestFile("this_os_test.dart", suiteTestOn: currentOS.name);
      _writeTestFile("other_os_test.dart",
          suiteTestOn: _otherOS, loadable: false);

      var result = _runUnittest(["."]);
      expect(result.stdout, contains("+2: All tests passed!"));
      expect(result.exitCode, equals(0));
    });
  });

  group("for group", () {
    test("runs a VM group on the VM", () {
      _writeTestFile("vm_test.dart", groupTestOn: "vm");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't run a Chrome group on the VM", () {
      _writeTestFile("chrome_test.dart", groupTestOn: "chrome");

      var result = _runUnittest(["chrome_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });

    test("runs a Chrome group on Chrome", () {
      _writeTestFile("chrome_test.dart", groupTestOn: "chrome");

      var result = _runUnittest(["--platform", "chrome", "chrome_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't run a VM group on Chrome", () {
      _writeTestFile("vm_test.dart", groupTestOn: "vm");

      var result = _runUnittest(["--platform", "chrome", "vm_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });
  });

  group("for test", () {
    test("runs a VM test on the VM", () {
      _writeTestFile("vm_test.dart", testTestOn: "vm");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't run a Chrome test on the VM", () {
      _writeTestFile("chrome_test.dart", testTestOn: "chrome");

      var result = _runUnittest(["chrome_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });

    test("runs a Chrome test on Chrome", () {
      _writeTestFile("chrome_test.dart", testTestOn: "chrome");

      var result = _runUnittest(["--platform", "chrome", "chrome_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't run a VM test on Chrome", () {
      _writeTestFile("vm_test.dart", testTestOn: "vm");

      var result = _runUnittest(["--platform", "chrome", "vm_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });
  });

  group("with suite, group, and test selectors", () {
    test("runs the test if all selectors match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "!browser",
          groupTestOn: "!js", testTestOn: "vm");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    test("doesn't runs the test if the suite doesn't match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "chrome",
          groupTestOn: "!js", testTestOn: "vm");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });

    test("doesn't runs the test if the group doesn't match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "!browser",
          groupTestOn: "chrome", testTestOn: "vm");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
    });

    test("doesn't runs the test if the test doesn't match", () {
      _writeTestFile("vm_test.dart", suiteTestOn: "!browser",
          groupTestOn: "!js", testTestOn: "chrome");

      var result = _runUnittest(["vm_test.dart"]);
      expect(result.stdout, contains("No tests ran."));
      expect(result.exitCode, equals(0));
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

  new File(p.join(_sandbox, filename)).writeAsStringSync(buffer.toString());
}

ProcessResult _runUnittest(List<String> args) =>
    runUnittest(args, workingDirectory: _sandbox);
