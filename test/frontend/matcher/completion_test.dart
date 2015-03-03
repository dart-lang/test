// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:unittest/unittest.dart';

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

    test("with an error", () {
      return runTest(() {
        expect(new Future.error('X'), completes);
      }).then((liveTest) {
        expectTestFailed(liveTest, startsWith(
            "Expected future to complete successfully, but it failed with X"));
      });
    });

    test("with a failure", () {
      return runTest(() {
        expect(new Future.error(new TestFailure('oh no')), completes);
      }).then((liveTest) {
        expectTestFailed(liveTest, "oh no");
      });
    });

    test("with a non-function", () {
      return runTest(() {
        expect(10, completes);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Expected: completes successfully\n"
            "  Actual: <10>\n");
      });
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

    test("with an error", () {
      return runTest(() {
        expect(new Future.error('X'), completion(isNull));
      }).then((liveTest) {
        expectTestFailed(liveTest, startsWith(
            "Expected future to complete successfully, but it failed with X"));
      });
    });

    test("with a failure", () {
      return runTest(() {
        expect(new Future.error(new TestFailure('oh no')), completion(isNull));
      }).then((liveTest) {
        expectTestFailed(liveTest, "oh no");
      });
    });

    test("with a non-function", () {
      return runTest(() {
        expect(10, completion(equals(10)));
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Expected: completes to a value that <10>\n"
            "  Actual: <10>\n");
      });
    });

    test("with an incorrect value", () {
      return runTest(() {
        expect(new Future.value('a'), completion(equals('b')));
      }).then((liveTest) {
        expectTestFailed(liveTest, startsWith(
            "Expected: 'b'\n"
            "  Actual: 'a'\n"
            "   Which: is different."));;
      });
    });
  });
}
