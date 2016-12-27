// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';
import 'dart:io';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

void main() {
  useSandbox();

  test("pauses the test runner for each file until the user presses enter", () {
    d.file("test1.dart", """
      import 'package:test/test.dart';

      void main() {
        print('loaded test 1!');

        test("success", () {});
      }
    """).create();

    d.file("test2.dart", """
      import 'package:test/test.dart';

      void main() {
        print('loaded test 2!');

        test("success", () {});
      }
    """).create();

    var test = runTest(["--pause-after-load", "test1.dart", "test2.dart"]);
    test.stdout.expect(consumeThrough("loaded test 1!"));
    test.stdout.expect(consumeThrough(inOrder([
      startsWith("Observatory URL: "),
      "The test runner is paused. Open the Observatory and set breakpoints. "
        "Once you're finished, return to",
      "this terminal and press Enter."
    ])));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync1((line) {
        expect(line, contains("+0: test1.dart: success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');

    test.stdout.expect(consumeThrough("loaded test 2!"));
    test.stdout.expect(consumeThrough(inOrder([
      startsWith("Observatory URL: "),
      "The test runner is paused. Open the Observatory and set breakpoints. "
        "Once you're finished, return to",
      "this terminal and press Enter."
    ])));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync1((line) {
        expect(line, contains("+1: test2.dart: success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');
    test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
    test.shouldExit(0);
  });

  test("pauses the test runner for each platform until the user presses enter",
      () {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        print('loaded test!');

        test("success", () {});
      }
    """).create();

    var test = runTest(
        ["--pause-after-load", "-p", "vm", "-p", "dartium", "test.dart"]);
    test.stdout.expect(consumeThrough("loaded test!"));
    test.stdout.expect(consumeThrough(inOrder([
      startsWith("Observatory URL: "),
      "The test runner is paused. Open the Observatory and set breakpoints. "
        "Once you're finished, return to",
      "this terminal and press Enter."
    ])));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync1((line) {
        expect(line, contains("+0: [VM] success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');

    test.stdout.expect(consumeThrough("loaded test!"));
    test.stdout.expect(consumeThrough(inOrder([
      "The test runner is paused. Open the remote debugger or the Observatory "
        "and set breakpoints. Once you're finished,",
      "return to this terminal and press Enter."
    ])));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync1((line) {
        expect(line, contains("+1: [Chrome] success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');
    test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
    test.shouldExit(0);
  }, tags: 'dartium');

  test("stops immediately if killed while paused", () {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        print('loaded test!');

        test("success", () {});
      }
    """).create();

    var test = runTest(["--pause-after-load", "test.dart"]);
    test.stdout.expect(consumeThrough("loaded test!"));
    test.stdout.expect(consumeThrough(inOrder([
      startsWith("Observatory URL: "),
      "The test runner is paused. Open the Observatory and set breakpoints. "
        "Once you're finished, return to",
      "this terminal and press Enter."
    ])));

    test.signal(ProcessSignal.SIGTERM);
    test.shouldExit();
    test.stderr.expect(isDone);
  }, testOn: "!windows");

  test("disables timeouts", () {
    d.file("test.dart", """
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        print('loaded test 1!');

        test("success", () async {
          await new Future.delayed(Duration.ZERO);
        }, timeout: new Timeout(Duration.ZERO));
      }
    """).create();

    var test = runTest(["--pause-after-load", "-n", "success", "test.dart"]);
    test.stdout.expect(consumeThrough("loaded test 1!"));
    test.stdout.expect(consumeThrough(inOrder([
      startsWith("Observatory URL: "),
      "The test runner is paused. Open the Observatory and set breakpoints. "
        "Once you're finished, return to",
      "this terminal and press Enter."
    ])));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync1((line) {
        expect(line, contains("+0: success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  // Regression test for #304.
  test("supports test name patterns", () {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        print('loaded test 1!');

        test("failure 1", () {});
        test("success", () {});
        test("failure 2", () {});
      }
    """).create();

    var test = runTest(["--pause-after-load", "-n", "success", "test.dart"]);
    test.stdout.expect(consumeThrough("loaded test 1!"));
    test.stdout.expect(consumeThrough(inOrder([
      startsWith("Observatory URL: "),
      "The test runner is paused. Open the Observatory and set breakpoints. "
        "Once you're finished, return to",
      "this terminal and press Enter."
    ])));

    schedule(() async {
      var nextLineFired = false;
      test.stdout.next().then(expectAsync1((line) {
        expect(line, contains("+0: success"));
        nextLineFired = true;
      }));

      // Wait a little bit to be sure that the tests don't start running without
      // our input.
      await new Future.delayed(new Duration(seconds: 2));
      expect(nextLineFired, isFalse);
    });

    test.writeLine('');
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  group("for a browser", () {
    test("pauses the test runner for each file until the user presses enter", () {
      d.file("test1.dart", """
        import 'package:test/test.dart';

        void main() {
          print('loaded test 1!');

          test("success", () {});
        }
      """).create();

      d.file("test2.dart", """
        import 'package:test/test.dart';

        void main() {
          print('loaded test 2!');

          test("success", () {});
        }
      """).create();

      var test = runTest(
          ["--pause-after-load", "-p", "dartium", "test1.dart", "test2.dart"]);
      test.stdout.expect(consumeThrough("loaded test 1!"));
      test.stdout.expect(consumeThrough(inOrder([
        startsWith("Observatory URL: "),
        "The test runner is paused. Open the dev console in Dartium or the "
            "Observatory and set breakpoints.",
        "Once you're finished, return to this terminal and press Enter."
      ])));

      schedule(() async {
        var nextLineFired = false;
        test.stdout.next().then(expectAsync1((line) {
          expect(line, contains("+0: test1.dart: success"));
          nextLineFired = true;
        }));

        // Wait a little bit to be sure that the tests don't start running without
        // our input.
        await new Future.delayed(new Duration(seconds: 2));
        expect(nextLineFired, isFalse);
      });

      test.writeLine('');

      test.stdout.expect(consumeThrough("loaded test 2!"));
      test.stdout.expect(consumeThrough(inOrder([
        startsWith("Observatory URL: "),
        "The test runner is paused. Open the dev console in Dartium or the "
            "Observatory and set breakpoints.",
        "Once you're finished, return to this terminal and press Enter."
      ])));

      schedule(() async {
        var nextLineFired = false;
        test.stdout.next().then(expectAsync1((line) {
          expect(line, contains("+1: test2.dart: success"));
          nextLineFired = true;
        }));

        // Wait a little bit to be sure that the tests don't start running without
        // our input.
        await new Future.delayed(new Duration(seconds: 2));
        expect(nextLineFired, isFalse);
      });

      test.writeLine('');
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    }, tags: 'dartium');

    test("stops immediately if killed while paused", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          print('loaded test!');

          test("success", () {});
        }
      """).create();

      var test = runTest(["--pause-after-load", "-p", "dartium", "test.dart"]);
      test.stdout.expect(consumeThrough("loaded test!"));
      test.stdout.expect(consumeThrough(inOrder([
        startsWith("Observatory URL: "),
        "The test runner is paused. Open the dev console in Dartium or the "
          "Observatory and set breakpoints.",
        "Once you're finished, return to this terminal and press Enter."
      ])));

      test.signal(ProcessSignal.SIGTERM);
      test.shouldExit();
      test.stderr.expect(isDone);
    }, tags: 'dartium', testOn: "!windows");
  });
}
