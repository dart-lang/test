// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:unittest/src/backend/invoker.dart';
import 'package:unittest/src/backend/state.dart';
import 'package:unittest/src/backend/suite.dart';
import 'package:unittest/unittest.dart';

import '../utils.dart';

void main() {
  var suite;
  setUp(() {
    lastState = null;
    suite = new Suite([]);
  });

  group("Invoker.current", () {
    var invoker = Invoker.current;
    test("returns null outside of a test body", () {
      expect(invoker, isNull);
    });

    test("returns the current invoker in a test body", () {
      var invoker;
      var liveTest = new LocalTest("test", () {
        invoker = Invoker.current;
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      return liveTest.run().then((_) {
        expect(invoker.liveTest, equals(liveTest));
      });
    });

    test("returns the current invoker in a test body after the test completes",
        () {
      var status;
      var completer = new Completer();
      var liveTest = new LocalTest("test", () {
        // Use [new Future] in particular to wait longer than a microtask for
        // the test to complete.
        new Future(() {
          status = Invoker.current.liveTest.state.status;
          completer.complete(Invoker.current);
        });
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      expect(liveTest.run(), completes);
      return completer.future.then((invoker) {
        expect(invoker.liveTest, equals(liveTest));
        expect(status, equals(Status.complete));
      });
    });

    test("returns the current invoker in a tearDown body", () {
      var invoker;
      var liveTest = new LocalTest("test", () {}, tearDown: () {
        invoker = Invoker.current;
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      return liveTest.run().then((_) {
        expect(invoker.liveTest, equals(liveTest));
      });
    });

    test("returns the current invoker in a tearDown body after the test "
        "completes", () {
      var status;
      var completer = new Completer();
      var liveTest = new LocalTest("test", () {}, tearDown: () {
        // Use [new Future] in particular to wait longer than a microtask for
        // the test to complete.
        new Future(() {
          status = Invoker.current.liveTest.state.status;
          completer.complete(Invoker.current);
        });
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      expect(liveTest.run(), completes);
      return completer.future.then((invoker) {
        expect(invoker.liveTest, equals(liveTest));
        expect(status, equals(Status.complete));
      });
    });
  });

  group("in a successful test,", () {
    test("the state changes from pending to running to complete", () {
      var stateInTest;
      var stateInTearDown;
      var liveTest;
      liveTest = new LocalTest("test", () {
        stateInTest = liveTest.state;
      }, tearDown: () {
        stateInTearDown = liveTest.state;
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      expect(liveTest.state.status, equals(Status.pending));
      expect(liveTest.state.result, equals(Result.success));

      var future = liveTest.run();

      expect(liveTest.state.status, equals(Status.running));
      expect(liveTest.state.result, equals(Result.success));

      return future.then((_) {
        expect(stateInTest.status, equals(Status.running));
        expect(stateInTest.result, equals(Result.success));

        expect(stateInTearDown.status, equals(Status.running));
        expect(stateInTearDown.result, equals(Result.success));

        expect(liveTest.state.status, equals(Status.complete));
        expect(liveTest.state.result, equals(Result.success));
      });
    });

    test("onStateChange fires for each state change", () {
      var liveTest = new LocalTest("test", () {}).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      var first = true;
      liveTest.onStateChange.listen(expectAsync((state) {
        if (first) {
          expect(state.status, equals(Status.running));
          first = false;
        } else {
          expect(state.status, equals(Status.complete));
        }
        expect(state.result, equals(Result.success));
      }, count: 2, max: 2));

      return liveTest.run();
    });

    test("onComplete completes once the test body and tearDown are done", () {
      var testRun = false;
      var tearDownRun = false;
      var liveTest = new LocalTest("test", () {
        testRun = true;
      }, tearDown: () {
        tearDownRun = true;
      }).load(suite);

      expect(liveTest.onComplete.then((_) {
        expect(testRun, isTrue);
        expect(tearDownRun, isTrue);
      }), completes);

      return liveTest.run();
    });
  });

  group("in a test with failures,", () {
    test("a synchronous throw is reported and causes the test to fail", () {
      var liveTest = new LocalTest("test", () {
        throw new TestFailure('oh no');
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a synchronous reported failure causes the test to fail", () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.handleError(new TestFailure("oh no"));
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a failure reported asynchronously during the test causes it to fail",
        () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => Invoker.current.handleError(new TestFailure("oh no")));
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a failure thrown asynchronously during the test causes it to fail",
        () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw new TestFailure("oh no"));
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a failure reported asynchronously after the test causes it to error",
        () {
      var liveTest = new LocalTest("test", () {
        new Future(() => Invoker.current.handleError(new TestFailure("oh no")));
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.success),
        const State(Status.complete, Result.failure),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState, equals(const State(Status.complete, Result.failure)));
        expect(error, isTestFailure("oh no"));
      }, (error) {
        expect(lastState, equals(const State(Status.complete, Result.error)));
        expect(error, equals(
             "This test failed after it had already completed. Make sure to "
                 "use [expectAsync]\n"
             "or the [completes] matcher when testing async code."));
      }]);

      return liveTest.run();
    });

    test("multiple asynchronous failures are reported", () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw new TestFailure("one"));
        new Future(() => throw new TestFailure("two"));
        new Future(() => throw new TestFailure("three"));
        new Future(() => throw new TestFailure("four"));
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.failure)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState.status, equals(Status.complete));
        expect(error, isTestFailure("one"));
      }, (error) {
        expect(error, isTestFailure("two"));
      }, (error) {
        expect(error, isTestFailure("three"));
      }, (error) {
        expect(error, isTestFailure("four"));
      }]);

      return liveTest.run();
    });

    test("a failure after an error doesn't change the state of the test", () {
      var liveTest = new LocalTest("test", () {
        new Future(() => throw new TestFailure("fail"));
        throw "error";
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState, equals(const State(Status.complete, Result.error)));
        expect(error, equals("error"));
      }, (error) {
        expect(error, isTestFailure("fail"));
      }]);

      return liveTest.run();
    });

    test("tearDown is run after an asynchronous failure", () {
      var stateDuringTearDown;
      var liveTest;
      liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw new TestFailure("oh no"));
      }, tearDown: () {
        stateDuringTearDown = liveTest.state;
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run().then((_) {
        expect(stateDuringTearDown,
            equals(const State(Status.complete, Result.failure)));
      });
    });
  });

  group("in a test with errors,", () {
    test("a synchronous throw is reported and causes the test to error", () {
      var liveTest = new LocalTest("test", () {
        throw 'oh no';
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("a synchronous reported error causes the test to error", () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.handleError("oh no");
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error reported asynchronously during the test causes it to error",
        () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => Invoker.current.handleError("oh no"));
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error thrown asynchronously during the test causes it to error",
        () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw "oh no");
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error reported asynchronously after the test causes it to error",
        () {
      var liveTest = new LocalTest("test", () {
        new Future(() => Invoker.current.handleError("oh no"));
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.success),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState, equals(const State(Status.complete, Result.error)));
        expect(error, equals("oh no"));
      }, (error) {
        expect(error, equals(
             "This test failed after it had already completed. Make sure to "
                 "use [expectAsync]\n"
             "or the [completes] matcher when testing async code."));
      }]);

      return liveTest.run();
    });

    test("multiple asynchronous errors are reported", () {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw "one");
        new Future(() => throw "two");
        new Future(() => throw "three");
        new Future(() => throw "four");
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState.status, equals(Status.complete));
        expect(error, equals("one"));
      }, (error) {
        expect(error, equals("two"));
      }, (error) {
        expect(error, equals("three"));
      }, (error) {
        expect(error, equals("four"));
      }]);

      return liveTest.run();
    });

    test("an error after a failure changes the state of the test", () {
      var liveTest = new LocalTest("test", () {
        new Future(() => throw "error");
        throw new TestFailure("fail");
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.failure),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState, equals(const State(Status.complete, Result.failure)));
        expect(error, isTestFailure("fail"));
      }, (error) {
        expect(lastState, equals(const State(Status.complete, Result.error)));
        expect(error, equals("error"));
      }]);

      return liveTest.run();
    });

    test("tearDown is run after an asynchronous error", () {
      var stateDuringTearDown;
      var liveTest;
      liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw "oh no");
      }, tearDown: () {
        stateDuringTearDown = liveTest.state;
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run().then((_) {
        expect(stateDuringTearDown,
            equals(const State(Status.complete, Result.error)));
      });
    });
  });

  test("a test doesn't complete until there are no outstanding callbacks",
      () {
    var outstandingCallbackRemoved = false;
    var liveTest = new LocalTest("test", () {
      Invoker.current.addOutstandingCallback();

      // Pump the event queue to make sure the test isn't coincidentally
      // completing after the outstanding callback is removed.
      pumpEventQueue().then((_) {
        outstandingCallbackRemoved = true;
        Invoker.current.removeOutstandingCallback();
      });
    }).load(suite);

    liveTest.onError.listen(expectAsync((_) {}, count: 0));

    return liveTest.run().then((_) {
      expect(outstandingCallbackRemoved, isTrue);
    });
  });

  test("a test's tearDown isn't run until there are no outstanding callbacks",
      () {
    var outstandingCallbackRemoved = false;
    var outstandingCallbackRemovedBeforeTeardown = false;
    var liveTest = new LocalTest("test", () {
      Invoker.current.addOutstandingCallback();
      pumpEventQueue().then((_) {
        outstandingCallbackRemoved = true;
        Invoker.current.removeOutstandingCallback();
      });
    }, tearDown: () {
      outstandingCallbackRemovedBeforeTeardown = outstandingCallbackRemoved;
    }).load(suite);

    liveTest.onError.listen(expectAsync((_) {}, count: 0));

    return liveTest.run().then((_) {
      expect(outstandingCallbackRemovedBeforeTeardown, isTrue);
    });
  });

  test("a test times out after 30 seconds", () {
    new FakeAsync().run((async) {
      var liveTest = new LocalTest("test", () {
        Invoker.current.addOutstandingCallback();
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState.status, equals(Status.complete));
        expect(error, new isInstanceOf<TimeoutException>());
      }]);

      liveTest.run();
      async.elapse(new Duration(seconds: 30));
    });
  });
}
