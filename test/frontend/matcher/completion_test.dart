// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test/src/backend/state.dart';

import '../../utils.dart';

void main() {
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

    test("with a non-function", () async {
      var liveTest = await runTestBody(() {
        expect(10, completes);
      });

      expectTestFailed(liveTest,
          "Expected: completes successfully\n"
          "  Actual: <10>\n");
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

    test("with a non-function", () async {
      var liveTest = await runTestBody(() {
        expect(10, completion(equals(10)));
      });

      expectTestFailed(liveTest,
          "Expected: completes to a value that <10>\n"
          "  Actual: <10>\n");
    });

    test("with an incorrect value", () async {
      var liveTest = await runTestBody(() {
        expect(new Future.value('a'), completion(equals('b')));
      });

      expectTestFailed(liveTest, startsWith(
          "Expected: 'b'\n"
          "  Actual: 'a'\n"
          "   Which: is different."));;
    });
  });
}
