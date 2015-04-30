// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../io.dart';

String _sandbox;

final _success = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""";

final _failure = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("failure", () => throw new TestFailure("oh no"));
}
""";

final _defaultConcurrency = math.max(1, Platform.numberOfProcessors ~/ 2);

final _browsers =
    "[vm (default), dartium, content-shell, chrome, phantomjs, firefox, webdriver" +
        (Platform.isMacOS ? ", safari" : "") +
        (Platform.isWindows ? ", ie" : "") + "]";

final _usage = """
Usage: pub run test:test [files or directories...]

-h, --help                     Shows this usage information.
    --version                  Shows the package's version.
-n, --name                     A substring of the name of the test to run.
                               Regular expression syntax is supported.

-N, --plain-name               A plain-text substring of the name of the test to run.
-p, --platform                 The platform(s) on which to run the tests.
                               $_browsers

-j, --concurrency=<threads>    The number of concurrent test suites run.
                               (defaults to $_defaultConcurrency)

    --pub-serve=<port>         The port of a pub serve instance serving "test/".
-r, --reporter                 The runner used to print test results.

          [compact]            A single line, updated continuously.
          [expanded]           A separate line for each update.

    --[no-]color               Whether to use terminal colors.
                               (auto-detected by default)
""";

void main() {
  setUp(() {
    _sandbox = createTempDir();
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("prints help information", () {
    var result = _runTest(["--help"]);
    expect(result.stdout, equals("""
Runs tests in this package.

$_usage"""));
    expect(result.exitCode, equals(exit_codes.success));
  });

  group("fails gracefully if", () {
    test("an invalid option is passed", () {
      var result = _runTest(["--asdf"]);
      expect(result.stderr, equals("""
Could not find an option named "asdf".

$_usage"""));
      expect(result.exitCode, equals(exit_codes.usage));
    });

    test("a non-existent file is passed", () {
      var result = _runTest(["file"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains('Failed to load "file": Does not exist.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("the default directory doesn't exist", () {
      var result = _runTest([]);
      expect(result.stderr, equals("""
No test files were passed and the default "test/" directory doesn't exist.

$_usage"""));
      expect(result.exitCode, equals(exit_codes.data));
    });

    test("a test file fails to load", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("invalid Dart file");
      var result = _runTest(["test.dart"]);

      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
          '  Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "  line 1 pos 1: unexpected token 'invalid'\n"
          "  invalid Dart file\n"
          "  ^\n")
      ]));
      expect(result.exitCode, equals(1));
    });

    // This is slightly different from the above test because it's an error
    // that's caught first by the analyzer when it's used to parse the file.
    test("a test file fails to parse", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("@TestOn)");
      var result = _runTest(["test.dart"]);

      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
          '  Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "  line 1 pos 8: unexpected token ')'\n"
          "  @TestOn)\n"
          "         ^\n")
      ]));
      expect(result.exitCode, equals(1));
    });

    test("an annotation's structure is invalid", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("@TestOn()\nlibrary foo;");
      var result = _runTest(["test.dart"]);

      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
          '  Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "  Error on line 1, column 8: TestOn takes 1 argument.\n"
          "  @TestOn()\n"
          "         ^^\n")
      ]));
      expect(result.exitCode, equals(1));
    });

    test("an annotation's contents are invalid", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("@TestOn('zim')\nlibrary foo;");
      var result = _runTest(["test.dart"]);

      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
          '  Failed to load "${p.relative(testPath, from: _sandbox)}":\n'
          "  Error on line 1, column 10: Undefined variable.\n"
          "  @TestOn('zim')\n"
          "           ^^^\n")
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file throws", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main() => throw 'oh no';");

      var result = _runTest(["test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": oh no')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file doesn't have a main defined", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void foo() {}");

      var result = _runTest(["test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": No '
                'top-level main() function defined.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file has a non-function main", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("int main;");

      var result = _runTest(["test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Top-level main getter is not a function.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file has a main with arguments", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      var result = _runTest(["test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Top-level main() function takes arguments.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("multiple load errors occur", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("invalid Dart file");
      var result = _runTest(["test.dart", "nonexistent.dart"]);

      expect(result.stdout, allOf([
        contains('test.dart: load error'),
        contains(
          '  Failed to load "test.dart":\n'
          "  line 1 pos 1: unexpected token 'invalid'\n"
          "  invalid Dart file\n"
          "  ^\n"),
        contains('nonexistent.dart: load error'),
        contains('Failed to load "nonexistent.dart": Does not exist.')
      ]));
    });

    // TODO(nweiz): test what happens when a test file is unreadable once issue
    // 15078 is fixed.
  });

  group("runs successful tests", () {
    test("defined in a single file", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runTest(["test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("defined in a directory", () {
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "${i}_test.dart"))
            .writeAsStringSync(_success);
      }

      var result = _runTest(["."]);
      expect(result.exitCode, equals(0));
    });

    test("defaulting to the test directory", () {
      new Directory(p.join(_sandbox, "test")).createSync();
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "test", "${i}_test.dart"))
            .writeAsStringSync(_success);
      }

      var result = _runTest([]);
      expect(result.exitCode, equals(0));
    });

    test("directly", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runDart([
        "--package-root=${p.join(packageDir, 'packages')}",
        "test.dart"
      ]);
      expect(result.stdout, contains("All tests passed!"));
      expect(result.exitCode, equals(0));
    });

    // Regression test; this broke in 0.12.0-beta.9.
    test("on a file in a subdirectory", () {
      new Directory(p.join(_sandbox, "dir")).createSync();
      new File(p.join(_sandbox, "dir", "test.dart"))
          .writeAsStringSync(_success);
      var result = _runTest(["dir/test.dart"]);
      expect(result.exitCode, equals(0));
    });
  });

  group("runs failing tests", () {
    test("defined in a single file", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runTest(["test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("defined in a directory", () {
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "${i}_test.dart"))
            .writeAsStringSync(_failure);
      }

      var result = _runTest(["."]);
      expect(result.exitCode, equals(1));
    });

    test("defaulting to the test directory", () {
      new Directory(p.join(_sandbox, "test")).createSync();
      for (var i = 0; i < 3; i++) {
        new File(p.join(_sandbox, "test", "${i}_test.dart"))
            .writeAsStringSync(_failure);
      }

      var result = _runTest([]);
      expect(result.exitCode, equals(1));
    });

    test("directly", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runDart([
        "--package-root=${p.join(packageDir, 'packages')}",
        "test.dart"
      ]);
      expect(result.stdout, contains("Some tests failed."));
      expect(result.exitCode, isNot(equals(0)));
    });
  });

  test("runs tests even when a file fails to load", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
    var result = _runTest(["test.dart", "nonexistent.dart"]);
    expect(result.stdout, contains("+1 -1: Some tests failed."));
    expect(result.exitCode, equals(1));
  });

  test("respects top-level @Timeout declarations", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@Timeout(const Duration(seconds: 0))

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("timeout", () {});
}
''');

    var result = _runTest(["test.dart"]);
    expect(result.stdout, contains("Test timed out after 0 seconds."));
    expect(result.stdout, contains("-1: Some tests failed."));
  });

  test("respects top-level @Skip declarations", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@Skip()

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''');

    var result = _runTest(["test.dart"]);
    expect(result.stdout, contains("+0 ~1: All tests skipped."));
  });

  group("with onPlatform", () {
    test("respects matching Skips", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {"vm": new Skip()});
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("+0 ~1: All tests skipped."));
    });

    test("ignores non-matching Skips", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {"chrome": new Skip()});
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("+1: All tests passed!"));
    });

    test("respects matching Timeouts", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {
    "vm": new Timeout(new Duration(seconds: 0))
  });
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("Test timed out after 0 seconds."));
      expect(result.stdout, contains("-1: Some tests failed."));
    });

    test("ignores non-matching Timeouts", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "chrome": new Timeout(new Duration(seconds: 0))
  });
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("+1: All tests passed!"));
    });

    test("applies matching platforms in order", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "vm": new Skip("first"),
    "vm || windows": new Skip("second"),
    "vm || linux": new Skip("third"),
    "vm || mac-os": new Skip("fourth"),
    "vm || android": new Skip("fifth")
  });
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("Skip: fifth"));
      expect(result.stdout, isNot(anyOf([
        contains("Skip: first"),
        contains("Skip: second"),
        contains("Skip: third"),
        contains("Skip: fourth")
      ])));
    });
  });

  group("with an @OnPlatform annotation", () {
    test("respects matching Skips", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@OnPlatform(const {"vm": const Skip()})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("+0 ~1: All tests skipped."));
    });

    test("ignores non-matching Skips", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@OnPlatform(const {"chrome": const Skip()})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("+1: All tests passed!"));
    });

    test("respects matching Timeouts", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@OnPlatform(const {
  "vm": const Timeout(const Duration(seconds: 0))
})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("Test timed out after 0 seconds."));
      expect(result.stdout, contains("-1: Some tests failed."));
    });

    test("ignores non-matching Timeouts", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@OnPlatform(const {
  "chrome": const Timeout(const Duration(seconds: 0))
})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''');

      var result = _runTest(["test.dart"]);
      expect(result.stdout, contains("+1: All tests passed!"));
    });
  });

  group("flags:", () {
    test("with the --color flag, uses colors", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runTest(["--color", "test.dart"]);
      // This is the color code for red.
      expect(result.stdout, contains("\u001b[31m"));
    });

    group("with the --name flag,", () {
      test("selects tests with matching names", () {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("selected 1", () {});
  test("nope", () => throw new TestFailure("oh no"));
  test("selected 2", () {});
}
""");

        var result = _runTest(["--name", "selected", "test.dart"]);
        expect(result.stdout, contains("+2: All tests passed!"));
        expect(result.exitCode, equals(0));
      });

      test("supports RegExp syntax", () {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test 1", () {});
  test("test 2", () => throw new TestFailure("oh no"));
  test("test 3", () {});
}
""");

        var result = _runTest(["--name", "test [13]", "test.dart"]);
        expect(result.stdout, contains("+2: All tests passed!"));
        expect(result.exitCode, equals(0));
      });

      test("produces an error when no tests match", () {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);

        var result = _runTest(["--name", "no match", "test.dart"]);
        expect(result.stderr,
            contains('No tests match regular expression "no match".'));
        expect(result.exitCode, equals(exit_codes.data));
      });

      test("doesn't filter out load exceptions", () {
        var result = _runTest(["--name", "name", "file"]);
        expect(result.stdout, allOf([
          contains('-1: load error'),
          contains('Failed to load "file": Does not exist.')
        ]));
        expect(result.exitCode, equals(1));
      });
    });

    group("with the --plain-name flag,", () {
      test("selects tests with matching names", () {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("selected 1", () {});
  test("nope", () => throw new TestFailure("oh no"));
  test("selected 2", () {});
}
""");

        var result = _runTest(["--plain-name", "selected", "test.dart"]);
        expect(result.stdout, contains("+2: All tests passed!"));
        expect(result.exitCode, equals(0));
      });

      test("doesn't support RegExp syntax", () {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test 1", () => throw new TestFailure("oh no"));
  test("test 2", () => throw new TestFailure("oh no"));
  test("test [12]", () {});
}
""");

        var result = _runTest(["--plain-name", "test [12]", "test.dart"]);
        expect(result.stdout, contains("+1: All tests passed!"));
        expect(result.exitCode, equals(0));
      });

      test("produces an error when no tests match", () {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);

        var result = _runTest(["--plain-name", "no match", "test.dart"]);
        expect(result.stderr,
            contains('No tests match "no match".'));
        expect(result.exitCode, equals(exit_codes.data));
      });
    });
  });
}

ProcessResult _runTest(List<String> args) =>
    runTest(args, workingDirectory: _sandbox);

ProcessResult _runDart(List<String> args) =>
    runDart(args, workingDirectory: _sandbox);
