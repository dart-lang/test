// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/src/backend/state.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group("supports a function with this many arguments:", () {
    test("0", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync(() {
          callbackRun = true;
        })();
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("1", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync((arg) {
          expect(arg, equals(1));
          callbackRun = true;
        })(1);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("2", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync((arg1, arg2) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          callbackRun = true;
        })(1, 2);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("3", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync((arg1, arg2, arg3) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          callbackRun = true;
        })(1, 2, 3);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("4", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync((arg1, arg2, arg3, arg4) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          expect(arg4, equals(4));
          callbackRun = true;
        })(1, 2, 3, 4);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("5", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync((arg1, arg2, arg3, arg4, arg5) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          expect(arg4, equals(4));
          expect(arg5, equals(5));
          callbackRun = true;
        })(1, 2, 3, 4, 5);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("6", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync((arg1, arg2, arg3, arg4, arg5, arg6) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          expect(arg4, equals(4));
          expect(arg5, equals(5));
          expect(arg6, equals(6));
          callbackRun = true;
        })(1, 2, 3, 4, 5, 6);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });
  });

  group("with optional arguments", () {
    test("allows them to be passed", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync(([arg = 1]) {
          expect(arg, equals(2));
          callbackRun = true;
        })(2);
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });

    test("allows them not to be passed", () async {
      var callbackRun = false;
      var liveTest = await runTestBody(() {
        expectAsync(([arg = 1]) {
          expect(arg, equals(1));
          callbackRun = true;
        })();
      });

      expectTestPassed(liveTest);
      expect(callbackRun, isTrue);
    });
  });

  test("doesn't support a function with 7 arguments", () {
    expect(() => expectAsync((_1, _2, _3, _4, _5, _6, _7) {}),
        throwsArgumentError);
  });

  group("by default", () {
    test("won't allow the test to complete until it's called", () {
      return expectTestBlocks(
          () => expectAsync(() {}),
          (callback) => callback());
    });

    test("may only be called once", () async {
      var liveTest = await runTestBody(() {
        var callback = expectAsync(() {});
        callback();
        callback();
      });

      expectTestFailed(liveTest,
          "Callback called more times than expected (1).");
    });
  });

  group("with count", () {
    test("won't allow the test to complete until it's called at least that "
        "many times", () async {
      var liveTest;
      var future;
      liveTest = createTest(() {
        var callback = expectAsync(() {}, count: 3);

        future = new Future.sync(() async {
          await pumpEventQueue();
          expect(liveTest.state.status, equals(Status.running));
          callback();

          await pumpEventQueue();
          expect(liveTest.state.status, equals(Status.running));
          callback();

          await pumpEventQueue();
          expect(liveTest.state.status, equals(Status.running));
          callback();
        });
      });

      await liveTest.run();
      expectTestPassed(liveTest);
      // Ensure that the outer test doesn't complete until the inner future
      // completes.
      await future;
    });

    test("will throw an error if it's called more than that many times", () async {
      var liveTest = await runTestBody(() {
        var callback = expectAsync(() {}, count: 3);
        callback();
        callback();
        callback();
        callback();
      });

      expectTestFailed(
          liveTest, "Callback called more times than expected (3).");
    });

    group("0,", () {
      test("won't block the test's completion", () {
        expectAsync(() {}, count: 0);
      });

      test("will throw an error if it's ever called", () async {
        var liveTest = await runTestBody(() {
          expectAsync(() {}, count: 0)();
        });

        expectTestFailed(
            liveTest, "Callback called more times than expected (0).");
      });
    });
  });

  group("with max", () {
    test("will allow the callback to be called that many times", () {
      var callback = expectAsync(() {}, max: 3);
      callback();
      callback();
      callback();
    });

    test("will allow the callback to be called fewer than that many times", () {
      var callback = expectAsync(() {}, max: 3);
      callback();
    });

    test("will throw an error if it's called more than that many times",
        () async {
      var liveTest = await runTestBody(() {
        var callback = expectAsync(() {}, max: 3);
        callback();
        callback();
        callback();
        callback();
      });

      expectTestFailed(
          liveTest, "Callback called more times than expected (3).");
    });

    test("-1, will allow the callback to be called any number of times", () {
      var callback = expectAsync(() {}, max: -1);
      for (var i = 0; i < 20; i++) {
        callback();
      }
    });
  });

  test("will throw an error if max is less than count", () {
    expect(() => expectAsync(() {}, max: 1, count: 2),
        throwsArgumentError);
  });

  group("expectAsyncUntil()", () {
    test("won't allow the test to complete until isDone returns true",
        () async {
      var liveTest;
      var future;
      liveTest = createTest(() {
        var done = false;
        var callback = expectAsyncUntil(() {}, () => done);

        future = new Future.sync(() async {
          await pumpEventQueue();
          expect(liveTest.state.status, equals(Status.running));
          callback();
          await pumpEventQueue();
          expect(liveTest.state.status, equals(Status.running));
          done = true;
          callback();
        });
      });

      await liveTest.run();
      expectTestPassed(liveTest);
      // Ensure that the outer test doesn't complete until the inner future
      // completes.
      await future;
    });

    test("doesn't call isDone until after the callback is called", () {
      var callbackRun = false;
      expectAsyncUntil(() => callbackRun = true, () {
        expect(callbackRun, isTrue);
        return true;
      })();
    });
  });

  group("with errors", () {
    test("reports them to the current test", () async {
      var liveTest = await runTestBody(() {
        expectAsync(() => throw new TestFailure('oh no'))();
      });

      expectTestFailed(liveTest, 'oh no');
    });

    test("swallows them and returns null", () async {
      var returnValue;
      var caughtError = false;
      var liveTest = await runTestBody(() {
        try {
          returnValue = expectAsync(() => throw new TestFailure('oh no'))();
        } on TestFailure catch (_) {
          caughtError = true;
        }
      });

      expectTestFailed(liveTest, 'oh no');
      expect(returnValue, isNull);
      expect(caughtError, isFalse);
    });
  });
}
