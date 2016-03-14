// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';
import 'dart:math' as math;

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/exit_codes.dart' as exit_codes;

import '../io.dart';

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
    "[vm (default), dartium, content-shell, chrome, phantomjs, firefox" +
        (Platform.isMacOS ? ", safari" : "") +
        (Platform.isWindows ? ", ie" : "") + "]";

final _usage = """
Usage: pub run test:test [files or directories...]

-h, --help                     Shows this usage information.
    --version                  Shows the package's version.

======== Selecting Tests
-n, --name                     A substring of the name of the test to run.
                               Regular expression syntax is supported.
                               If passed multiple times, tests must match all substrings.

-N, --plain-name               A plain-text substring of the name of the test to run.
                               If passed multiple times, tests must match all substrings.

-t, --tags                     Run only tests with all of the specified tags.
                               Supports boolean selector syntax.

-x, --exclude-tags             Don't run tests with any of the specified tags.
                               Supports boolean selector syntax.

======== Running Tests
-p, --platform                 The platform(s) on which to run the tests.
                               $_browsers

-P, --preset                   The configuration preset(s) to use.
-j, --concurrency=<threads>    The number of concurrent test suites run.
                               (defaults to "$_defaultConcurrency")

    --pub-serve=<port>         The port of a pub serve instance serving "test/".
    --timeout                  The default test timeout. For example: 15s, 2x, none
                               (defaults to "30s")

    --pause-after-load         Pauses for debugging before any tests execute.
                               Implies --concurrency=1 and --timeout=none.
                               Currently only supported for browser tests.

======== Output
-r, --reporter                 The runner used to print test results.

          [compact]            A single line, updated continuously.
          [expanded]           A separate line for each update.
          [json]               A machine-readable format (see https://goo.gl/0HRhdZ).

    --verbose-trace            Whether to emit stack traces with core library frames.
    --js-trace                 Whether to emit raw JavaScript stack traces for browser tests.
    --[no-]color               Whether to use terminal colors.
                               (auto-detected by default)
""";

void main() {
  useSandbox();

  test("prints help information", () {
    var test = runTest(["--help"]);
    expectStdoutEquals(test, """
Runs tests in this package.

$_usage""");
    test.shouldExit(0);
  });

  group("fails gracefully if", () {
    test("an invalid option is passed", () {
      var test = runTest(["--asdf"]);
      expectStderrEquals(test, """
Could not find an option named "asdf".

$_usage""");
      test.shouldExit(exit_codes.usage);
    });

    test("a non-existent file is passed", () {
      var test = runTest(["file"]);
      test.stdout.expect(containsInOrder([
        '-1: loading file',
        'Failed to load "file": Does not exist.'
      ]));
      test.shouldExit(1);
    });

    test("the default directory doesn't exist", () {
      var test = runTest([]);
      expectStderrEquals(test, """
No test files were passed and the default "test/" directory doesn't exist.

$_usage""");
      test.shouldExit(exit_codes.data);
    });

    test("a test file fails to load", () {
      d.file("test.dart", "invalid Dart file").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart":',
        "line 1 pos 1: unexpected token 'invalid'",
        "invalid Dart file",
        "^"
      ]));
      test.shouldExit(1);
    });

    // This syntax error is detected lazily, and so requires some extra
    // machinery to support.
    test("a test file fails to parse due to a missing semicolon", () {
      d.file("test.dart", "void main() {foo}").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart":',
        'line 1 pos 17: semicolon expected',
        'void main() {foo}',
        '                ^'
      ]));
      test.shouldExit(1);
    });

    // This is slightly different from the above test because it's an error
    // that's caught first by the analyzer when it's used to parse the file.
    test("a test file fails to parse", () {
      d.file("test.dart", "@TestOn)").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart":',
        "line 1 pos 8: unexpected token ')'",
        "@TestOn)",
        "       ^"
      ]));
      test.shouldExit(1);
    });

    test("an annotation's structure is invalid", () {
      d.file("test.dart", "@TestOn()\nlibrary foo;").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart":',
        "Error on line 1, column 8: TestOn takes 1 argument.",
        "@TestOn()",
        "       ^^"
      ]));
      test.shouldExit(1);
    });

    test("an annotation's contents are invalid", () {
      d.file("test.dart", "@TestOn('zim')\nlibrary foo;").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart":',
        "Error on line 1, column 10: Undefined variable.",
        "@TestOn('zim')",
        "         ^^^"
      ]));
      test.shouldExit(1);
    });

    test("a test file throws", () {
      d.file("test.dart", "void main() => throw 'oh no';").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": oh no'
      ]));
      test.shouldExit(1);
    });

    test("a test file doesn't have a main defined", () {
      d.file("test.dart", "void foo() {}").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": No top-level main() function defined.'
      ]));
      test.shouldExit(1);
    });

    test("a test file has a non-function main", () {
      d.file("test.dart", "int main;").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": Top-level main getter is not a function.'
      ]));
      test.shouldExit(1);
    });

    test("a test file has a main with arguments", () {
      d.file("test.dart", "void main(arg) {}").create();
      var test = runTest(["test.dart"]);

      test.stdout.expect(containsInOrder([
        '-1: loading test.dart',
        'Failed to load "test.dart": Top-level main() function takes arguments.'
      ]));
      test.shouldExit(1);
    });

    test("multiple load errors occur", () {
      d.file("test.dart", "invalid Dart file").create();
      var test = runTest(["test.dart", "nonexistent.dart"]);

      test.stdout.expect(containsInOrder([
        'loading nonexistent.dart',
        'Failed to load "nonexistent.dart": Does not exist.',
        'loading test.dart',
        'Failed to load "test.dart":',
        "line 1 pos 1: unexpected token 'invalid'",
        "invalid Dart file",
        "^"
      ]));
      test.shouldExit(1);
    });

    // TODO(nweiz): test what happens when a test file is unreadable once issue
    // 15078 is fixed.
  });

  group("runs successful tests", () {
    test("defined in a single file", () {
      d.file("test.dart", _success).create();
      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("defined in a directory", () {
      for (var i = 0; i < 3; i++) {
        d.file("${i}_test.dart", _success).create();
      }

      var test = runTest(["."]);
      test.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      test.shouldExit(0);
    });

    test("defaulting to the test directory", () {
      d.dir("test", new Iterable.generate(3, (i) {
        return d.file("${i}_test.dart", _success);
      })).create();

      var test = runTest([]);
      test.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      test.shouldExit(0);
    });

    test("directly", () {
      d.file("test.dart", _success).create();
      var test = runDart(["test.dart"]);

      test.stdout.expect(consumeThrough(contains("All tests passed!")));
      test.shouldExit(0);
    });

    // Regression test; this broke in 0.12.0-beta.9.
    test("on a file in a subdirectory", () {
      d.dir("dir", [d.file("test.dart", _success)]).create();

      var test = runTest(["dir/test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });
  });

  group("runs failing tests", () {
    test("defined in a single file", () {
      d.file("test.dart", _failure).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
      test.shouldExit(1);
    });

    test("defined in a directory", () {
      for (var i = 0; i < 3; i++) {
        d.file("${i}_test.dart", _failure).create();
      }

      var test = runTest(["."]);
      test.stdout.expect(consumeThrough(contains("-3: Some tests failed.")));
      test.shouldExit(1);
    });

    test("defaulting to the test directory", () {
      d.dir("test", new Iterable.generate(3, (i) {
        return d.file("${i}_test.dart", _failure);
      })).create();

      var test = runTest([]);
      test.stdout.expect(consumeThrough(contains("-3: Some tests failed.")));
      test.shouldExit(1);
    });

    test("directly", () {
      d.file("test.dart", _failure).create();
      var test = runDart(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("Some tests failed.")));
      test.shouldExit(255);
    });
  });

  test("runs tests even when a file fails to load", () {
    d.file("test.dart", _success).create();

    var test = runTest(["test.dart", "nonexistent.dart"]);
    test.stdout.expect(consumeThrough(contains("+1 -1: Some tests failed.")));
    test.shouldExit(1);
  });

  test("respects top-level @Skip declarations", () {
    d.file("test.dart", '''
@Skip()

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''').create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+0 ~1: All tests skipped.")));
    test.shouldExit(0);
  });

  group("with onPlatform", () {
    test("respects matching Skips", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {"vm": new Skip()});
}
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+0 ~1: All tests skipped.")));
      test.shouldExit(0);
    });

    test("ignores non-matching Skips", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {"chrome": new Skip()});
}
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("respects matching Timeouts", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () async {
    await new Future.delayed(Duration.ZERO);
    throw 'oh no';
  }, onPlatform: {
    "vm": new Timeout(Duration.ZERO)
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

    test("ignores non-matching Timeouts", () {
      d.file("test.dart", '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "chrome": new Timeout(new Duration(seconds: 0))
  });
}
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("applies matching platforms in order", () {
      d.file("test.dart", '''
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
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.fork().expect(never(contains("Skip: first")));
      test.stdout.fork().expect(never(contains("Skip: second")));
      test.stdout.fork().expect(never(contains("Skip: third")));
      test.stdout.fork().expect(never(contains("Skip: fourth")));
      test.stdout.expect(consumeThrough(contains("Skip: fifth")));
      test.shouldExit(0);
    });
  });

  group("with an @OnPlatform annotation", () {
    test("respects matching Skips", () {
      d.file("test.dart", '''
@OnPlatform(const {"vm": const Skip()})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no');
}
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+0 ~1: All tests skipped.")));
      test.shouldExit(0);
    });

    test("ignores non-matching Skips", () {
      d.file("test.dart", '''
@OnPlatform(const {"chrome": const Skip()})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("respects matching Timeouts", () {
      d.file("test.dart", '''
@OnPlatform(const {
  "vm": const Timeout(const Duration(seconds: 0))
})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () async {
    await new Future.delayed(Duration.ZERO);
    throw 'oh no';
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

    test("ignores non-matching Timeouts", () {
      d.file("test.dart", '''
@OnPlatform(const {
  "chrome": const Timeout(const Duration(seconds: 0))
})

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });
  });

  test("with the --color flag, uses colors", () {
    d.file("test.dart", _failure).create();
    var test = runTest(["--color", "test.dart"]);
    // This is the color code for red.
    test.stdout.expect(consumeThrough(contains("\u001b[31m")));
    test.shouldExit();
  });
}
