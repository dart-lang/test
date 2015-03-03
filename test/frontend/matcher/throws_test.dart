// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../../utils.dart';

void main() {
  group("synchronous", () {
    group("[throws]", () {
      test("with a function that throws an error", () {
        expect(() => throw 'oh no', throws);
      });

      test("with a function that doesn't throw", () {
        return runTest(() {
          expect(() {}, throws);
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected: throws\n"
              "  Actual: <Closure: () => dynamic>\n"
              "   Which: did not throw\n");
        });
      });

      test("with a non-function", () {
        return runTest(() {
          expect(10, throws);
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected: throws\n"
              "  Actual: <10>\n"
              "   Which: is not a Function or Future\n");
        });
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

      test("with a function that doesn't throw", () {
        return runTest(() {
          expect(() {}, throwsA('oh no'));
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected: throws 'oh no'\n"
              "  Actual: <Closure: () => dynamic>\n"
              "   Which: did not throw\n");
        });
      });

      test("with a non-function", () {
        return runTest(() {
          expect(10, throwsA('oh no'));
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected: throws 'oh no'\n"
              "  Actual: <10>\n"
              "   Which: is not a Function or Future\n");
        });
      });

      test("with a function that throws the wrong error", () {
        return runTest(() {
          expect(() => throw 'aw dang', throwsA('oh no'));
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected: throws 'oh no'\n"
              "  Actual: <Closure: () => dynamic>\n"
              "   Which: threw 'aw dang'\n");
        });
      });
    });
  });

  group("asynchronous", () {
    group("[throws]", () {
      test("with a Future that throws an error", () {
        expect(new Future.error('oh no'), throws);
      });

      test("with a Future that doesn't throw", () {
        return runTest(() {
          expect(new Future.value(), throws);
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected future to fail, but succeeded with 'null'.");
        });
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

      test("with a Future that doesn't throw", () {
        return runTest(() {
          expect(new Future.value(), throwsA('oh no'));
        }).then((liveTest) {
          expectTestFailed(liveTest,
              "Expected future to fail, but succeeded with 'null'.");
        });
      });

      test("with a Future that throws the wrong error", () {
        return runTest(() {
          expect(new Future.error('aw dang'), throwsA('oh no'));
        }).then((liveTest) {
          expectTestFailed(liveTest, startsWith(
              "Expected: throws 'oh no'\n"
              "  Actual: <Closure: () => dynamic>\n"
              "   Which: threw 'aw dang'\n"));
        });
      });

      test("won't let the test end until the Future completes", () {
        return expectTestBlocks(() {
          var completer = new Completer();
          expect(completer.future, throwsA('oh no'));
          return completer;
        }, (completer) => completer.completeError('oh no'));
      });
    });
  });
}
