// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unittest/src/util/io.dart';
import 'package:unittest/unittest.dart';

import '../io.dart';

String _sandbox;

final _vm = """
@TestOn("vm")

import 'package:unittest/unittest.dart';

void main() {
  test("success", () {});
}
""";

final _chrome = """
@TestOn("chrome")

// Make sure that loading this test file on the VM will break.
import 'dart:html';

import 'package:unittest/unittest.dart';

void main() {
  test("success", () {});
}
""";

final _thisOS = """
@TestOn("$currentOS")

import 'package:unittest/unittest.dart';

void main() {
  test("success", () {});
}
""";

final _otherOS = """
@TestOn("${Platform.isWindows ? "mac-os" : "windows"}")

// Make sure that loading this test file on the VM will break.
import 'dart:html';

import 'package:unittest/unittest.dart';

void main() {
  test("success", () {});
}
""";

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('unittest_').path;
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("runs a test suite on a matching platform", () {
    new File(p.join(_sandbox, "vm_test.dart")).writeAsStringSync(_vm);

    var result = _runUnittest(["vm_test.dart"]);
    expect(result.stdout, contains("All tests passed!"));
    expect(result.exitCode, equals(0));
  });

  test("doesn't run a test suite on a non-matching platform", () {
    new File(p.join(_sandbox, "vm_test.dart")).writeAsStringSync(_vm);

    var result = _runUnittest(["--platform", "chrome", "vm_test.dart"]);
    expect(result.stdout, contains("No tests ran."));
    expect(result.exitCode, equals(0));
  });

  test("runs a test suite on a matching operating system", () {
    new File(p.join(_sandbox, "os_test.dart")).writeAsStringSync(_thisOS);

    var result = _runUnittest(["os_test.dart"]);
    expect(result.stdout, contains("All tests passed!"));
    expect(result.exitCode, equals(0));
  });

  test("doesn't run a test suite on a non-matching operating system", () {
    new File(p.join(_sandbox, "os_test.dart")).writeAsStringSync(_otherOS);

    var result = _runUnittest(["os_test.dart"]);
    expect(result.stdout, contains("No tests ran."));
    expect(result.exitCode, equals(0));
  });

  test("only loads matching files when loading as a group", () {
    new File(p.join(_sandbox, "vm_test.dart")).writeAsStringSync(_vm);
    new File(p.join(_sandbox, "chrome_test.dart")).writeAsStringSync(_chrome);
    new File(p.join(_sandbox, "this_os_test.dart")).writeAsStringSync(_thisOS);
    new File(p.join(_sandbox, "other_os_test.dart"))
        .writeAsStringSync(_otherOS);

    var result = _runUnittest(["."]);
    expect(result.stdout, contains("+2: All tests passed!"));
    expect(result.exitCode, equals(0));
  });
}

ProcessResult _runUnittest(List<String> args) =>
    runUnittest(args, workingDirectory: _sandbox);
