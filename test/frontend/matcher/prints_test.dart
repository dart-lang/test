// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../../utils.dart';

void main() {
  group("synchronous", () {
    test("passes with an expected print", () {
      expect(() => print("Hello, world!"), prints("Hello, world!\n"));
    });

    test("combines multiple prints", () {
      expect(() {
        print("Hello");
        print("World!");
      }, prints("Hello\nWorld!\n"));
    });

    test("works with a Matcher", () {
      expect(() => print("Hello, world!"), prints(contains("Hello")));
    });

    test("describes a failure nicely", () {
      return runTest(() {
        expect(() => print("Hello, world!"), prints("Goodbye, world!\n"));
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Expected: prints 'Goodbye, world!\\n'\n"
            "  ''\n"
            "  Actual: <Closure: () => dynamic>\n"
            "   Which: printed 'Hello, world!\\n'\n"
            "  ''\n"
            "   Which: is different.\n"
            "Expected: Goodbye, w ...\n"
            "  Actual: Hello, wor ...\n"
            "          ^\n"
            " Differ at offset 0\n");
      });
    });

    test("describes a failure with a non-descriptive Matcher nicely", () {
      return runTest(() {
        expect(() => print("Hello, world!"), prints(contains("Goodbye")));
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Expected: prints contains 'Goodbye'\n"
            "  Actual: <Closure: () => dynamic>\n"
            "   Which: printed 'Hello, world!\\n'\n"
            "  ''\n");
      });
    });

    test("describes a failure with no text nicely", () {
      return runTest(() {
        expect(() {}, prints(contains("Goodbye")));
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Expected: prints contains 'Goodbye'\n"
            "  Actual: <Closure: () => dynamic>\n"
            "   Which: printed nothing.\n");
      });
    });

    test("with a non-function", () {
      return runTest(() {
        expect(10, prints(contains("Goodbye")));
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Expected: prints contains 'Goodbye'\n"
            "  Actual: <10>\n");
      });
    });
  });

  group('asynchronous', () {
    test("passes with an expected print", () {
      expect(() => new Future(() => print("Hello, world!")),
          prints("Hello, world!\n"));
    });

    test("combines multiple prints", () {
      expect(() => new Future(() {
        print("Hello");
        print("World!");
      }), prints("Hello\nWorld!\n"));
    });

    test("works with a Matcher", () {
      expect(() => new Future(() => print("Hello, world!")),
          prints(contains("Hello")));
    });

    test("describes a failure nicely", () {
      return runTest(() {
        expect(() => new Future(() => print("Hello, world!")),
            prints("Goodbye, world!\n"));
      }).then((liveTest) {
        expectTestFailed(liveTest, startsWith(
            "Expected: prints 'Goodbye, world!\\n'\n"
            "  ''\n"
            "  Actual: <Closure: () => dynamic>\n"
            "   Which: printed 'Hello, world!\\n'\n"
            "  ''\n"
            "   Which: is different.\n"
            "Expected: Goodbye, w ...\n"
            "  Actual: Hello, wor ...\n"
            "          ^\n"
            " Differ at offset 0"));
      });
    });

    test("describes a failure with a non-descriptive Matcher nicely", () {
      return runTest(() {
        expect(() => new Future(() => print("Hello, world!")),
            prints(contains("Goodbye")));
      }).then((liveTest) {
        expectTestFailed(liveTest, startsWith(
            "Expected: prints contains 'Goodbye'\n"
            "  Actual: <Closure: () => dynamic>\n"
            "   Which: printed 'Hello, world!\\n'\n"
            "  ''"));
      });
    });

    test("describes a failure with no text nicely", () {
      return runTest(() {
        expect(() => new Future.value(), prints(contains("Goodbye")));
      }).then((liveTest) {
        expectTestFailed(liveTest, startsWith(
            "Expected: prints contains 'Goodbye'\n"
            "  Actual: <Closure: () => dynamic>\n"
            "   Which: printed nothing."));
      });
    });

    test("won't let the test end until the Future completes", () {
      return expectTestBlocks(() {
        var completer = new Completer();
        expect(() => completer.future, prints(isEmpty));
        return completer;
      }, (completer) => completer.complete());
    });
  });
}
