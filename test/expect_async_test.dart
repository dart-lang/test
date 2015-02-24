// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/src/backend/state.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

void main() {
  group("supports a function with this many arguments:", () {
    test("0", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync(() {
          callbackRun = true;
        })();
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("1", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync((arg) {
          expect(arg, equals(1));
          callbackRun = true;
        })(1);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("2", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync((arg1, arg2) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          callbackRun = true;
        })(1, 2);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("3", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync((arg1, arg2, arg3) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          callbackRun = true;
        })(1, 2, 3);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("4", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync((arg1, arg2, arg3, arg4) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          expect(arg4, equals(4));
          callbackRun = true;
        })(1, 2, 3, 4);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("5", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync((arg1, arg2, arg3, arg4, arg5) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          expect(arg4, equals(4));
          expect(arg5, equals(5));
          callbackRun = true;
        })(1, 2, 3, 4, 5);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("6", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync((arg1, arg2, arg3, arg4, arg5, arg6) {
          expect(arg1, equals(1));
          expect(arg2, equals(2));
          expect(arg3, equals(3));
          expect(arg4, equals(4));
          expect(arg5, equals(5));
          expect(arg6, equals(6));
          callbackRun = true;
        })(1, 2, 3, 4, 5, 6);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });
  });

  group("with optional arguments", () {
    test("allows them to be passed", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync(([arg = 1]) {
          expect(arg, equals(2));
          callbackRun = true;
        })(2);
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
    });

    test("allows them not to be passed", () {
      var callbackRun = false;
      return runTest(() {
        expectAsync(([arg = 1]) {
          expect(arg, equals(1));
          callbackRun = true;
        })();
      }).then((liveTest) {
        expectTestPassed(liveTest);
        expect(callbackRun, isTrue);
      });
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

    test("may only be called once", () {
      return runTest(() {
        var callback = expectAsync(() {});
        callback();
        callback();
      }).then((liveTest) {
        expectTestFailed(liveTest,
            "Callback called more times than expected (1).");
      });
    });
  });

  group("with count", () {
    test("won't allow the test to complete until it's called at least that "
        "many times", () {
      var liveTest;
      var future;
      liveTest = createTest(() {
        var callback = expectAsync(() {}, count: 3);
        future = pumpEventQueue().then((_) {
          expect(liveTest.state.status, equals(Status.running));
          callback();
          return pumpEventQueue();
        }).then((_) {
          expect(liveTest.state.status, equals(Status.running));
          callback();
          return pumpEventQueue();
        }).then((_) {
          expect(liveTest.state.status, equals(Status.running));
          callback();
        });
      });

      return liveTest.run().then((_) {
        expectTestPassed(liveTest);
        // Ensure that the outer test doesn't complete until the inner future
        // completes.
        return future;
      });
    });

    test("will throw an error if it's called more than that many times", () {
      return runTest(() {
        var callback = expectAsync(() {}, count: 3);
        callback();
        callback();
        callback();
        callback();
      }).then((liveTest) {
        expectTestFailed(
            liveTest, "Callback called more times than expected (3).");
      });
    });

    group("0,", () {
      test("won't block the test's completion", () {
        expectAsync(() {}, count: 0);
      });

      test("will throw an error if it's ever called", () {
        return runTest(() {
          expectAsync(() {}, count: 0)();
        }).then((liveTest) {
          expectTestFailed(
              liveTest, "Callback called more times than expected (0).");
        });
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

    test("will throw an error if it's called more than that many times", () {
      return runTest(() {
        var callback = expectAsync(() {}, max: 3);
        callback();
        callback();
        callback();
        callback();
      }).then((liveTest) {
        expectTestFailed(
            liveTest, "Callback called more times than expected (3).");
      });
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
    test("won't allow the test to complete until isDone returns true", () {
      var liveTest;
      var future;
      liveTest = createTest(() {
        var done = false;
        var callback = expectAsyncUntil(() {}, () => done);

        future = pumpEventQueue().then((_) {
          expect(liveTest.state.status, equals(Status.running));
          callback();
          return pumpEventQueue();
        }).then((_) {
          expect(liveTest.state.status, equals(Status.running));
          done = true;
          callback();
        });
      });

      return liveTest.run().then((_) {
        expectTestPassed(liveTest);
        // Ensure that the outer test doesn't complete until the inner future
        // completes.
        return future;
      });
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
    test("reports them to the current test", () {
      return runTest(() {
        expectAsync(() => throw new TestFailure('oh no'))();
      }).then((liveTest) {
        expectTestFailed(liveTest, 'oh no');
      });
    });

    test("swallows them and returns null", () {
      var returnValue;
      var caughtError = false;
      return runTest(() {
        try {
          returnValue = expectAsync(() => throw new TestFailure('oh no'))();
        } on TestFailure catch (_) {
          caughtError = true;
        }
      }).then((liveTest) {
        expectTestFailed(liveTest, 'oh no');
        expect(returnValue, isNull);
        expect(caughtError, isFalse);
      });
    });
  });
}
