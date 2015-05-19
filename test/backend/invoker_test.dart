// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:test/src/backend/invoker.dart';
import 'package:test/src/backend/metadata.dart';
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/suite.dart';
import 'package:test/test.dart';

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

    test("returns the current invoker in a test body", () async {
      var invoker;
      var liveTest = _localTest(() {
        invoker = Invoker.current;
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      await liveTest.run();
      expect(invoker.liveTest, equals(liveTest));
    });

    test("returns the current invoker in a test body after the test completes",
        () async {
      var status;
      var completer = new Completer();
      var liveTest = _localTest(() {
        // Use [new Future] in particular to wait longer than a microtask for
        // the test to complete.
        new Future(() {
          status = Invoker.current.liveTest.state.status;
          completer.complete(Invoker.current);
        });
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      expect(liveTest.run(), completes);
      var invoker = await completer.future;
      expect(invoker.liveTest, equals(liveTest));
      expect(status, equals(Status.complete));
    });

    test("returns the current invoker in a tearDown body", () async {
      var invoker;
      var liveTest = _localTest(() {}, tearDown: () {
        invoker = Invoker.current;
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      await liveTest.run();
      expect(invoker.liveTest, equals(liveTest));
    });

    test("returns the current invoker in a tearDown body after the test "
        "completes", () async {
      var status;
      var completer = new Completer();
      var liveTest = _localTest(() {}, tearDown: () {
        // Use [new Future] in particular to wait longer than a microtask for
        // the test to complete.
        new Future(() {
          status = Invoker.current.liveTest.state.status;
          completer.complete(Invoker.current);
        });
      }).load(suite);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      expect(liveTest.run(), completes);
      var invoker = await completer.future;
      expect(invoker.liveTest, equals(liveTest));
      expect(status, equals(Status.complete));
    });
  });

  group("in a successful test,", () {
    test("the state changes from pending to running to complete", () async {
      var stateInTest;
      var stateInTearDown;
      var liveTest;
      liveTest = _localTest(() {
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

      await future;

      expect(stateInTest.status, equals(Status.running));
      expect(stateInTest.result, equals(Result.success));

      expect(stateInTearDown.status, equals(Status.running));
      expect(stateInTearDown.result, equals(Result.success));

      expect(liveTest.state.status, equals(Status.complete));
      expect(liveTest.state.result, equals(Result.success));
    });

    test("onStateChange fires for each state change", () {
      var liveTest = _localTest(() {}).load(suite);
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
      var liveTest = _localTest(() {
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
      var liveTest = _localTest(() {
        throw new TestFailure('oh no');
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a synchronous reported failure causes the test to fail", () {
      var liveTest = _localTest(() {
        Invoker.current.handleError(new TestFailure("oh no"));
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a failure reported asynchronously during the test causes it to fail",
        () {
      var liveTest = _localTest(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => Invoker.current.handleError(new TestFailure("oh no")));
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a failure thrown asynchronously during the test causes it to fail",
        () {
      var liveTest = _localTest(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw new TestFailure("oh no"));
      }).load(suite);

      expectSingleFailure(liveTest);
      return liveTest.run();
    });

    test("a failure reported asynchronously after the test causes it to error",
        () {
      var liveTest = _localTest(() {
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
      var liveTest = _localTest(() {
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
      var liveTest = _localTest(() {
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

    test("tearDown is run after an asynchronous failure", () async {
      var stateDuringTearDown;
      var liveTest;
      liveTest = _localTest(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw new TestFailure("oh no"));
      }, tearDown: () {
        stateDuringTearDown = liveTest.state;
      }).load(suite);

      expectSingleFailure(liveTest);
      await liveTest.run();
      expect(stateDuringTearDown,
          equals(const State(Status.complete, Result.failure)));
    });
  });

  group("in a test with errors,", () {
    test("a synchronous throw is reported and causes the test to error", () {
      var liveTest = _localTest(() {
        throw 'oh no';
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("a synchronous reported error causes the test to error", () {
      var liveTest = _localTest(() {
        Invoker.current.handleError("oh no");
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error reported asynchronously during the test causes it to error",
        () {
      var liveTest = _localTest(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => Invoker.current.handleError("oh no"));
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error thrown asynchronously during the test causes it to error",
        () {
      var liveTest = _localTest(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw "oh no");
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error reported asynchronously after the test causes it to error",
        () {
      var liveTest = _localTest(() {
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
      var liveTest = _localTest(() {
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
      var liveTest = _localTest(() {
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

    test("tearDown is run after an asynchronous error", () async {
      var stateDuringTearDown;
      var liveTest;
      liveTest = _localTest(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw "oh no");
      }, tearDown: () {
        stateDuringTearDown = liveTest.state;
      }).load(suite);

      expectSingleError(liveTest);
      await liveTest.run();
      expect(stateDuringTearDown,
          equals(const State(Status.complete, Result.error)));
    });

    test("an asynchronous error in tearDown causes the test to error", () {
      var liveTest = _localTest(() {}, tearDown: () {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw "oh no");
      }).load(suite);

      expectSingleError(liveTest);
      return liveTest.run();
    });

    test("an error reported in the test body after tearDown begins running "
        "doesn't stop tearDown", () async {
      var tearDownComplete = false;;
      var completer = new Completer();

      var liveTest;
      liveTest = _localTest(() {
        completer.future.then((_) => throw "not again");
        throw "oh no";
      }, tearDown: () {
        completer.complete();

        // Pump the event queue so that we will run the following code after the
        // test body has thrown a second error.
        Invoker.current.addOutstandingCallback();
        pumpEventQueue().then((_) {
          Invoker.current.removeOutstandingCallback();
          tearDownComplete = true;
        });
      }).load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [
        (error) {
          expect(lastState.status, equals(Status.complete));
          expect(error, equals("oh no"));
        },
        (error) => expect(error, equals("not again"))
      ]);

      await liveTest.run();
      expect(tearDownComplete, isTrue);
    });
  });

  test("a test doesn't complete until there are no outstanding callbacks",
      () async {
    var outstandingCallbackRemoved = false;
    var liveTest = _localTest(() {
      Invoker.current.addOutstandingCallback();

      // Pump the event queue to make sure the test isn't coincidentally
      // completing after the outstanding callback is removed.
      pumpEventQueue().then((_) {
        outstandingCallbackRemoved = true;
        Invoker.current.removeOutstandingCallback();
      });
    }).load(suite);

    liveTest.onError.listen(expectAsync((_) {}, count: 0));

    await liveTest.run();
    expect(outstandingCallbackRemoved, isTrue);
  });

  test("a test's tearDown isn't run until there are no outstanding callbacks",
      () async {
    var outstandingCallbackRemoved = false;
    var outstandingCallbackRemovedBeforeTeardown = false;
    var liveTest = _localTest(() {
      Invoker.current.addOutstandingCallback();
      pumpEventQueue().then((_) {
        outstandingCallbackRemoved = true;
        Invoker.current.removeOutstandingCallback();
      });
    }, tearDown: () {
      outstandingCallbackRemovedBeforeTeardown = outstandingCallbackRemoved;
    }).load(suite);

    liveTest.onError.listen(expectAsync((_) {}, count: 0));

    await liveTest.run();
    expect(outstandingCallbackRemovedBeforeTeardown, isTrue);
  });

  test("a test's tearDown doesn't complete until there are no outstanding "
      "callbacks", () async {
    var outstandingCallbackRemoved = false;
    var liveTest = _localTest(() {}, tearDown: () {
      Invoker.current.addOutstandingCallback();

      // Pump the event queue to make sure the test isn't coincidentally
      // completing after the outstanding callback is removed.
      pumpEventQueue().then((_) {
        outstandingCallbackRemoved = true;
        Invoker.current.removeOutstandingCallback();
      });
    }).load(suite);

    liveTest.onError.listen(expectAsync((_) {}, count: 0));

    await liveTest.run();
    expect(outstandingCallbackRemoved, isTrue);
  });

  test("a test body's outstanding callbacks can't complete its tearDown",
      () async {
    var outstandingCallbackRemoved = false;
    var completer = new Completer();
    var liveTest = _localTest(() {
      // Once the tearDown runs, remove an outstanding callback to see if it
      // causes the tearDown to complete.
      completer.future.then((_) {
        Invoker.current.removeOutstandingCallback();
      });
    }, tearDown: () {
      Invoker.current.addOutstandingCallback();

      // This will cause the test BODY to remove an outstanding callback, which
      // shouldn't cause the test to complete.
      completer.complete();

      pumpEventQueue().then((_) {
        outstandingCallbackRemoved = true;
        Invoker.current.removeOutstandingCallback();
      });
    }).load(suite);

    liveTest.onError.listen(expectAsync((_) {}, count: 0));

    await liveTest.run();
    expect(outstandingCallbackRemoved, isTrue);
  });

  test("a test's prints are captured and reported", () {
    expect(() {
      var liveTest = _localTest(() {
        print("Hello,");
        return new Future(() => print("world!"));
      }).load(suite);

      expect(liveTest.onPrint.take(2).toList(),
          completion(equals(["Hello,", "world!"])));

      return liveTest.run();
    }, prints(isEmpty));
  });

  group("timeout:", () {
    test("a test times out after 30 seconds by default", () {
      new FakeAsync().run((async) {
        var liveTest = _localTest(() {
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

    test("a test's custom timeout takes precedence", () {
      new FakeAsync().run((async) {
        var liveTest = _localTest(() {
          Invoker.current.addOutstandingCallback();
        }, metadata: new Metadata(
            timeout: new Timeout(new Duration(seconds: 15)))).load(suite);

        expectStates(liveTest, [
          const State(Status.running, Result.success),
          const State(Status.complete, Result.error)
        ]);

        expectErrors(liveTest, [(error) {
          expect(lastState.status, equals(Status.complete));
          expect(error, new isInstanceOf<TimeoutException>());
        }]);

        liveTest.run();
        async.elapse(new Duration(seconds: 15));
      });
    });

    test("a timeout factor is applied on top of the 30s default", () {
      new FakeAsync().run((async) {
        var liveTest = _localTest(() {
          Invoker.current.addOutstandingCallback();
        }, metadata: new Metadata(timeout: new Timeout.factor(0.5)))
            .load(suite);

        expectStates(liveTest, [
          const State(Status.running, Result.success),
          const State(Status.complete, Result.error)
        ]);

        expectErrors(liveTest, [(error) {
          expect(lastState.status, equals(Status.complete));
          expect(error, new isInstanceOf<TimeoutException>());
        }]);

        liveTest.run();
        async.elapse(new Duration(seconds: 15));
      });
    });
  });
}

LocalTest _localTest(body(), {tearDown(), Metadata metadata}) {
  if (metadata == null) metadata = new Metadata();
  return new LocalTest("test", metadata, body, tearDown: tearDown);
}
