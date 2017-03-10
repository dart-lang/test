// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import '../../utils.dart';

void main() {
  group("synchronous", () {
    group("[throws]", () {
      test("with a function that throws an error", () {
        expect(() => throw 'oh no', throws);
      });

      test("with a function that doesn't throw", () async {
        var closure = () {};
        var liveTest = await runTestBody(() {
          expect(closure, throws);
        });

        expectTestFailed(liveTest, allOf([
          startsWith(
              "Expected: throws\n"
              "  Actual: <"),
          endsWith(">\n"
              "   Which: returned <null>\n")
        ]));
      });

      test("with a non-function", () async {
        var liveTest = await runTestBody(() {
          expect(10, throws);
        });

        expectTestFailed(liveTest,
            "Expected: throws\n"
            "  Actual: <10>\n"
            "   Which: was not a Function or Future\n");
      });
    });

    group("[throwsA]", () {
      test("with a function that throws an identical error", () {
        expect(() => throw 'oh no', throwsA('oh no'));
      });

      test("with a function that throws a matching error", () {
        expect(() => throw new FormatException("bad"),
            throwsA(isFormatException));
      });

      test("with a function that doesn't throw", () async {
        var closure = () {};
        var liveTest = await runTestBody(() {
          expect(closure, throwsA('oh no'));
        });

        expectTestFailed(liveTest, allOf([
          startsWith(
              "Expected: throws 'oh no'\n"
              "  Actual: <"),
          endsWith(">\n"
              "   Which: returned <null>\n")
        ]));
      });

      test("with a non-function", () async {
        var liveTest = await runTestBody(() {
          expect(10, throwsA('oh no'));
        });

        expectTestFailed(liveTest,
            "Expected: throws 'oh no'\n"
            "  Actual: <10>\n"
            "   Which: was not a Function or Future\n");
      });

      test("with a function that throws the wrong error", () async {
        var liveTest = await runTestBody(() {
          expect(() => throw 'aw dang', throwsA('oh no'));
        });

        expectTestFailed(liveTest, allOf([
          startsWith(
              "Expected: throws 'oh no'\n"
              "  Actual: <"),
          contains(">\n"
              "   Which: threw 'aw dang'\n"
              "          stack"),
          endsWith(
              "          which is different.\n"
              "                Expected: oh no\n"
              "                  Actual: aw dang\n"
              "                          ^\n"
              "                 Differ at offset 0\n")
        ]));
      });
    });
  });

  group("asynchronous", () {
    group("[throws]", () {
      test("with a Future that throws an error", () {
        expect(new Future.error('oh no'), throws);
      });

      test("with a Future that doesn't throw", () async {
        var liveTest = await runTestBody(() {
          expect(new Future.value(), throws);
        });

        expectTestFailed(liveTest, allOf([
          startsWith(
              "Expected: throws\n"
              "  Actual: <"),
          endsWith(">\n"
              "   Which: emitted <null>\n")
        ]));
      });

      test("won't let the test end until the Future completes", () {
        return expectTestBlocks(() {
          var completer = new Completer();
          expect(completer.future, throws);
          return completer;
        }, (completer) => completer.completeError('oh no'));
      });
    });

    group("[throwsA]", () {
      test("with a Future that throws an identical error", () {
        expect(new Future.error('oh no'), throwsA('oh no'));
      });

      test("with a Future that throws a matching error", () {
        expect(new Future.error(new FormatException("bad")),
            throwsA(isFormatException));
      });

      test("with a Future that doesn't throw", () async {
        var liveTest = await runTestBody(() {
          expect(new Future.value(), throwsA('oh no'));
        });

        expectTestFailed(liveTest, allOf([
          startsWith(
              "Expected: throws 'oh no'\n"
              "  Actual: <"),
          endsWith(">\n"
              "   Which: emitted <null>\n")
        ]));
      });

      test("with a Future that throws the wrong error", () async {
        var liveTest = await runTestBody(() {
          expect(new Future.error('aw dang'), throwsA('oh no'));
        });

        expectTestFailed(liveTest, allOf([
          startsWith(
              "Expected: throws 'oh no'\n"
              "  Actual: <"),
          contains(">\n"
              "   Which: threw 'aw dang'\n")
        ]));
      });

      test("won't let the test end until the Future completes", () {
        return expectTestBlocks(() {
          var completer = new Completer();
          expect(completer.future, throwsA('oh no'));
          return completer;
        }, (completer) => completer.completeError('oh no'));
      });

      test("blocks expectLater's Future", () async {
        var completer = new Completer();
        var fired = false;
        expectLater(completer.future, throwsArgumentError).then((_) {
          fired = true;
        });

        await pumpEventQueue();
        expect(fired, isFalse);

        completer.completeError(new ArgumentError("oh no"));
        await pumpEventQueue();
        expect(fired, isTrue);
      });
    });
  });
}
