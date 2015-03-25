// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unittest/src/util/exit_codes.dart' as exit_codes;
import 'package:unittest/unittest.dart';

import '../io.dart';

String _sandbox;

final _success = """
import 'dart:async';

import 'package:unittest/unittest.dart';

void main() {
  test("success", () {});
}
""";

final _failure = """
import 'dart:async';

import 'package:unittest/unittest.dart';

void main() {
  test("failure", () => throw new TestFailure("oh no"));
}
""";

final _usage = """
Usage: pub run unittest:unittest [files or directories...]

-h, --help          Shows this usage information.
-p, --platform      The platform(s) on which to run the tests.
                    [vm (default), chrome]

    --[no-]color    Whether to use terminal colors.
                    (auto-detected by default)
""";

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('unittest_').path;
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("prints help information", () {
    var result = _runUnittest(["--help"]);
    expect(result.stdout, equals("""
Runs tests in this package.

$_usage"""));
    expect(result.exitCode, equals(exit_codes.success));
  });

  group("fails gracefully if", () {
    test("an invalid option is passed", () {
      var result = _runUnittest(["--asdf"]);
      expect(result.stderr, equals("""
Could not find an option named "asdf".

$_usage"""));
      expect(result.exitCode, equals(exit_codes.usage));
    });

    test("a non-existent file is passed", () {
      var result = _runUnittest(["file"]);
      expect(result.stderr, equals('Failed to load "file": Does not exist.\n'));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("the default directory doesn't exist", () {
      var result = _runUnittest([]);
      expect(result.stderr, equals(
          'Failed to load "test": No test files were passed and the default '
              'directory doesn\'t exist.\n'));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("a test file fails to load", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("invalid Dart file");
      var result = _runUnittest(["test.dart"]);

      expect(result.stderr, equals(
          'Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "line 1 pos 1: unexpected token 'invalid'\n"
          "invalid Dart file\n"
          "^\n"));
      expect(result.exitCode, equals(exit_codes.data));
    });

    // This is slightly different from the above test because it's an error
    // that's caught first by the analyzer when it's used to parse the file.
    test("a test file fails to parse", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("@TestOn)");
      var result = _runUnittest(["test.dart"]);

      expect(result.stderr, equals(
          'Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "line 1 pos 8: unexpected token ')'\n"
          "@TestOn)\n"
          "       ^\n"));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("an annotation's structure is invalid", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("@TestOn()\nlibrary foo;");
      var result = _runUnittest(["test.dart"]);

      expect(result.stderr, equals(
          'Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "Error on line 1, column 8: TestOn takes one argument.\n"
          "@TestOn()\n"
          "       ^^\n"));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("a test file throws", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main() => throw 'oh no';");

      var result = _runUnittest(["test.dart"]);
      expect(result.stderr, startsWith(
          'Failed to load "${p.relative(testPath, from: _sandbox)}": oh no\n'));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("a test file doesn't have a main defined", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void foo() {}");

      var result = _runUnittest(["test.dart"]);
      expect(result.stderr, startsWith(
          'Failed to load "${p.relative(testPath, from: _sandbox)}": No '
              'top-level main() function defined.\n'));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("a test file has a non-function main", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("int main;");

      var result = _runUnittest(["test.dart"]);
      expect(result.stderr, startsWith(
          'Failed to load "${p.relative(testPath, from: _sandbox)}": Top-level '
              'main getter is not a function.\n'));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("a test file has a main with arguments", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      var result = _runUnittest(["test.dart"]);
      expect(result.stderr, startsWith(
          'Failed to load "${p.relative(testPath, from: _sandbox)}": Top-level '
              'main() function takes arguments.\n'));
      expect(result.exitCode, equals(exit_codes.data));
    });

    // TODO(nweiz): test what happens when a test file is unreadable once issue
    // 15078 is fixed.
  });

  group("runs successful tests", () {
    test("defined in a single file", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("defined in a directory", () {
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "${i}_test.dart"))
            .writeAsStringSync(_success);
      }

      var result = _runUnittest(["."]);
      expect(result.exitCode, equals(0));
    });

    test("defaulting to the test directory", () {
      new Directory(p.join(_sandbox, "test")).createSync();
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "test", "${i}_test.dart"))
            .writeAsStringSync(_success);
      }

      var result = _runUnittest([]);
      expect(result.exitCode, equals(0));
    });

    test("directly", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runDart([
        "--package-root=${p.join(packageDir, 'packages')}",
        "test.dart"
      ]);
      expect(result.stdout, contains("All tests passed!"));
    });
  });

  group("runs failing tests", () {
    test("defined in a single file", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("defined in a directory", () {
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "${i}_test.dart"))
            .writeAsStringSync(_failure);
      }

      var result = _runUnittest(["."]);
      expect(result.exitCode, equals(1));
    });

    test("defaulting to the test directory", () {
      new Directory(p.join(_sandbox, "test")).createSync();
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "test", "${i}_test.dart"))
            .writeAsStringSync(_failure);
      }

      var result = _runUnittest([]);
      expect(result.exitCode, equals(1));
    });

    test("directly", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runDart([
        "--package-root=${p.join(packageDir, 'packages')}",
        "test.dart"
      ]);
      expect(result.stdout, contains("Some tests failed."));
    });
  });

  group("flags", () {
    test("with the --color flag, uses colors", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["--color", "test.dart"]);
      // This is the color code for red.
      expect(result.stdout, contains("\u001b[31m"));
    });
  });
}

ProcessResult _runUnittest(List<String> args) =>
    runUnittest(args, workingDirectory: _sandbox);

ProcessResult _runDart(List<String> args) =>
    runDart(args, workingDirectory: _sandbox);
