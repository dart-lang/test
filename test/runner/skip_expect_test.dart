// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

void main() {
  useSandbox();

  group("a skipped expect", () {
    test("marks the test as skipped", () {
      d
          .file(
              "test.dart",
              """
        import 'package:test/test.dart';

        void main() {
          test("skipped", () => expect(1, equals(2), skip: true));
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("~1: All tests skipped.")));
      test.shouldExit(0);
    });

    test("prints the skip reason if there is one", () {
      d
          .file(
              "test.dart",
              """
        import 'package:test/test.dart';

        void main() {
          test("skipped", () => expect(1, equals(2),
              reason: "1 is 2", skip: "is failing"));
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: skipped",
        "  Skip expect: is failing",
        "~1: All tests skipped."
      ]));
      test.shouldExit(0);
    });

    test("prints the expect reason if there's no skip reason", () {
      d
          .file(
              "test.dart",
              """
        import 'package:test/test.dart';

        void main() {
          test("skipped", () => expect(1, equals(2),
              reason: "1 is 2", skip: true));
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: skipped",
        "  Skip expect (1 is 2).",
        "~1: All tests skipped."
      ]));
      test.shouldExit(0);
    });

    test("prints the matcher description if there are no reasons", () {
      d
          .file(
              "test.dart",
              """
        import 'package:test/test.dart';

        void main() {
          test("skipped", () => expect(1, equals(2), skip: true));
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder(
          ["+0: skipped", "  Skip expect (<2>).", "~1: All tests skipped."]));
      test.shouldExit(0);
    });

    test("still allows the test to fail", () {
      d
          .file(
              "test.dart",
              """
        import 'package:test/test.dart';

        void main() {
          test("failing", () {
            expect(1, equals(2), skip: true);
            expect(1, equals(2));
          });
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: failing",
        "  Skip expect (<2>).",
        "+0 -1: failing [E]",
        "  Expected: <2>",
        "    Actual: <1>",
        "+0 -1: Some tests failed."
      ]));
      test.shouldExit(1);
    });
  });

  group("errors", () {
    test("when called after the test succeeded", () {
      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          var skipCompleter = new Completer();
          var waitCompleter = new Completer();
          test("skip", () {
            skipCompleter.future.then((_) {
              waitCompleter.complete();
              expect(1, equals(2), skip: true);
            });
          });

          // Trigger the skip completer in a following test to ensure that it
          // only fires after skip has completed successfully.
          test("wait", () async {
            skipCompleter.complete();
            await waitCompleter.future;
          });
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: skip",
        "+1: wait",
        "+0 -1: skip",
        "This test was marked as skipped after it had already completed. "
            "Make sure to use",
        "[expectAsync] or the [completes] matcher when testing async code.",
        "+1 -1: Some tests failed."
      ]));
      test.shouldExit(1);
    });

    test("when an invalid type is used for skip", () {
      d
          .file(
              "test.dart",
              """
        import 'package:test/test.dart';

        void main() {
          test("failing", () {
            expect(1, equals(2), skip: 10);
          });
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder(
          ["Invalid argument (skip)", "+0 -1: Some tests failed."]));
      test.shouldExit(1);
    });
  });
}
