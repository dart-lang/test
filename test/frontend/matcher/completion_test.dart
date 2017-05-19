// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test/src/backend/state.dart';

import '../../utils.dart';

void main() {
  group("[doesNotComplete]", () {
    test("succeeds when provided a non future", () {
      expect(10, doesNotComplete);
    });

    test("succeeds when a future does not complete", () {
      var completer = new Completer();
      expect(completer.future, doesNotComplete);
    });

    test("fails when a future does complete", () async {
      var liveTest = await runTestBody(() {
        var completer = new Completer();
        completer.complete(null);
        expect(completer.future, doesNotComplete);
      });

      expectTestFailed(
          liveTest,
          "Expected: does not complete\n"
          "  Actual: <Instance of '_Future'>\n"
          "   Which: completed with a value of null\n");
    });

    test("fails when a future completes after the expect", () async {
      var liveTest = await runTestBody(() {
        var completer = new Completer();
        expect(completer.future, doesNotComplete);
        completer.complete(null);
      });

      expectTestFailed(
          liveTest,
          "Expected: does not complete\n"
          "  Actual: <Instance of '_Future'>\n"
          "   Which: completed with a value of null\n");
    });

    test(
        "succeeds if a future completes after the provided timesToPump"
        "through the event queue", () async {
      var liveTest = await runTestBody(() {
        var completer = new Completer();
        expect(completer.future, doesNotCompleteAfter(2));
        new Future(() async {
          await pumpEventQueue(2);
          completer.complete(null);
        });
      });

      expectTestPassed(liveTest);
    });

    test("fails when a future eventually completes", () async {
      var liveTest = await runTestBody(() {
        var completer = new Completer();
        expect(completer.future, doesNotComplete);
        new Future(() async {
          await pumpEventQueue(10);
        }).then(completer.complete);
      });

      expectTestFailed(
          liveTest,
          "Expected: does not complete\n"
          "  Actual: <Instance of '_Future'>\n"
          "   Which: completed with a value of null\n");
    });
  });
  group("[completes]", () {
    test("blocks the test until the Future completes", () {
      return expectTestBlocks(() {
        var completer = new Completer();
        expect(completer.future, completes);
        return completer;
      }, (completer) => completer.complete());
    });

    test("with an error", () async {
      var liveTest = await runTestBody(() {
        expect(new Future.error('X'), completes);
      });

      expect(liveTest.state.status, equals(Status.complete));
      expect(liveTest.state.result, equals(Result.error));
      expect(liveTest.errors, hasLength(1));
      expect(liveTest.errors.first.error, equals('X'));
    });

    test("with a failure", () async {
      var liveTest = await runTestBody(() {
        expect(new Future.error(new TestFailure('oh no')), completes);
      });

      expectTestFailed(liveTest, "oh no");
    });

    test("with a non-future", () async {
      var liveTest = await runTestBody(() {
        expect(10, completes);
      });

      expectTestFailed(
          liveTest,
          "Expected: completes successfully\n"
          "  Actual: <10>\n"
          "   Which: was not a Future\n");
    });

    test("with a successful future", () {
      expect(new Future.value('1'), completes);
    });
  });

  group("[completion]", () {
    test("blocks the test until the Future completes", () {
      return expectTestBlocks(() {
        var completer = new Completer();
        expect(completer.future, completion(isNull));
        return completer;
      }, (completer) => completer.complete());
    });

    test("with an error", () async {
      var liveTest = await runTestBody(() {
        expect(new Future.error('X'), completion(isNull));
      });

      expect(liveTest.state.status, equals(Status.complete));
      expect(liveTest.state.result, equals(Result.error));
      expect(liveTest.errors, hasLength(1));
      expect(liveTest.errors.first.error, equals('X'));
    });

    test("with a failure", () async {
      var liveTest = await runTestBody(() {
        expect(new Future.error(new TestFailure('oh no')), completion(isNull));
      });

      expectTestFailed(liveTest, "oh no");
    });

    test("with a non-future", () async {
      var liveTest = await runTestBody(() {
        expect(10, completion(equals(10)));
      });

      expectTestFailed(
          liveTest,
          "Expected: completes to a value that <10>\n"
          "  Actual: <10>\n"
          "   Which: was not a Future\n");
    });

    test("with an incorrect value", () async {
      var liveTest = await runTestBody(() {
        expect(new Future.value('a'), completion(equals('b')));
      });

      expectTestFailed(
          liveTest,
          allOf([
            startsWith("Expected: completes to a value that 'b'\n"
                "  Actual: <"),
            endsWith(">\n"
                "   Which: emitted 'a'\n"
                "            which is different.\n"
                "                  Expected: b\n"
                "                    Actual: a\n"
                "                            ^\n"
                "                   Differ at offset 0\n")
          ]));
    });

    test("blocks expectLater's Future", () async {
      var completer = new Completer();
      var fired = false;
      expectLater(completer.future, completion(equals(1))).then((_) {
        fired = true;
      });

      await pumpEventQueue();
      expect(fired, isFalse);

      completer.complete(1);
      await pumpEventQueue();
      expect(fired, isTrue);
    });
  });
}
