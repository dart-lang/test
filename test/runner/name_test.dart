// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
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

void main() {
  useSandbox();

  group("with the --name flag,", () {
    test("selects tests with matching names", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("selected 1", () {});
          test("nope", () => throw new TestFailure("oh no"));
          test("selected 2", () {});
        }
      """).create();

      var test = runTest(["--name", "selected", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    });

    test("supports RegExp syntax", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test 1", () {});
          test("test 2", () => throw new TestFailure("oh no"));
          test("test 3", () {});
        }
      """).create();

      var test = runTest(["--name", "test [13]", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    });

    test("selects more narrowly when passed multiple times", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("selected 1", () {});
          test("nope", () => throw new TestFailure("oh no"));
          test("selected 2", () {});
        }
      """).create();

      var test = runTest(["--name", "selected", "--name", "1", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("produces an error when no tests match", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["--name", "no match", "test.dart"]);
      test.stderr.expect(consumeThrough(
          contains('No tests match regular expression "no match".')));
      test.shouldExit(exit_codes.data);
    });

    test("doesn't filter out load exceptions", () {
      var test = runTest(["--name", "name", "file"]);
      test.stdout.expect(containsInOrder([
        '-1: loading file',
        '  Failed to load "file": Does not exist.'
      ]));
      test.shouldExit(1);
    });
  });

  group("with the --plain-name flag,", () {
    test("selects tests with matching names", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("selected 1", () {});
          test("nope", () => throw new TestFailure("oh no"));
          test("selected 2", () {});
        }
      """).create();

      var test = runTest(["--plain-name", "selected", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't support RegExp syntax", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test 1", () => throw new TestFailure("oh no"));
          test("test 2", () => throw new TestFailure("oh no"));
          test("test [12]", () {});
        }
      """).create();

      var test = runTest(["--plain-name", "test [12]", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("selects more narrowly when passed multiple times", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("selected 1", () {});
          test("nope", () => throw new TestFailure("oh no"));
          test("selected 2", () {});
        }
      """).create();

      var test = runTest(
          ["--plain-name", "selected", "--plain-name", "1", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("produces an error when no tests match", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["--plain-name", "no match", "test.dart"]);
      test.stderr.expect(
          consumeThrough(contains('No tests match "no match".')));
      test.shouldExit(exit_codes.data);
    });
  });

  test("--name and --plain-name together narrow the selection", () {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("selected 1", () {});
        test("nope", () => throw new TestFailure("oh no"));
        test("selected 2", () {});
      }
    """).create();

    var test = runTest(
        ["--name", ".....", "--plain-name", "e", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
    test.shouldExit(0);
  });
}