// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:unittest/src/invoker.dart';
import 'package:unittest/src/isolate_test.dart';
import 'package:unittest/src/live_test.dart';
import 'package:unittest/src/remote_exception.dart';
import 'package:unittest/src/state.dart';
import 'package:unittest/src/suite.dart';
import 'package:unittest/src/vm_listener.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

/// An isolate that's been spun up for the current test.
///
/// This is tracked so that it can be killed once the test is done.
Isolate _isolate;

/// A live test that's running for the current test.
///
/// This is tracked so that it can be closed once the test is done.
LiveTest _liveTest;

void main() {
  tearDown(() {
    if (_isolate != null) _isolate.kill(Isolate.IMMEDIATE);
    _isolate = null;

    if (_liveTest != null) _liveTest.close();
    _liveTest = null;
  });

  test("sends a list of available tests on startup", () {
    return _spawnIsolate(_successfulTests).then((receivePort) {
      return receivePort.first;
    }).then((response) {
      expect(response, containsPair("type", "success"));
      expect(response, contains("tests"));

      var tests = response["tests"];
      expect(tests, hasLength(3));
      expect(tests[0], containsPair("name", "successful 1"));
      expect(tests[1], containsPair("name", "successful 2"));
      expect(tests[2], containsPair("name", "successful 3"));
    });
  });

  test("sends an error response if loading fails", () {
    return _spawnIsolate(_loadError).then((receivePort) {
      return receivePort.first;
    }).then((response) {
      expect(response, containsPair("type", "error"));
      expect(response, contains("error"));

      var error = RemoteException.deserialize(response["error"]).error;
      expect(error.message, equals("oh no"));
      expect(error.type, equals("String"));
    });
  });

  test("sends an error response on a NoSuchMethodError", () {
    return _spawnIsolate(_noSuchMethodError).then((receivePort) {
      return receivePort.first;
    }).then((response) {
      expect(response, containsPair("type", "loadException"));
      expect(response,
          containsPair("message", "No top-level main() function defined."));
    });
  });

  test("sends an error response on non-function main", () {
    return _spawnIsolate(_nonFunction).then((receivePort) {
      return receivePort.first;
    }).then((response) {
      expect(response, containsPair("type", "loadException"));
      expect(response,
          containsPair("message", "Top-level main getter is not a function."));
    });
  });

  test("sends an error response on wrong-arity main", () {
    return _spawnIsolate(_wrongArity).then((receivePort) {
      return receivePort.first;
    }).then((response) {
      expect(response, containsPair("type", "loadException"));
      expect(
          response,
          containsPair(
              "message",
              "Top-level main() function takes arguments."));
    });
  });

  group("in a successful test", () {
    test("the state changes from pending to running to complete", () {
      return _isolateTest(_successfulTests).then((liveTest) {
        liveTest.onError.listen(expectAsync((_) {}, count: 0));

        expect(liveTest.state,
            equals(const State(Status.pending, Result.success)));

        var future = liveTest.run();

        expect(liveTest.state,
            equals(const State(Status.running, Result.success)));

        return future.then((_) {
          expect(liveTest.state,
              equals(const State(Status.complete, Result.success)));
        });
      });
    });

    test("onStateChange fires for each state change", () {
      return _isolateTest(_successfulTests).then((liveTest) {
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
    });
  });

  group("in a test with failures", () {
    test("a failure reported causes the test to fail", () {
      return _isolateTest(_failingTest).then((liveTest) {
        expectSingleFailure(liveTest);
        return liveTest.run();
      });
    });

    test("a failure reported asynchronously after the test causes it to error",
        () {
      return _isolateTest(_failAfterSucceedTest).then((liveTest) {
        expectStates(liveTest, [
          const State(Status.running, Result.success),
          const State(Status.complete, Result.success),
          const State(Status.complete, Result.failure),
          const State(Status.complete, Result.error)
        ]);

        expectErrors(liveTest, [(error) {
          expect(lastState,
              equals(const State(Status.complete, Result.failure)));
          expect(error, isTestFailure("oh no"));
        }, (error) {
          expect(lastState, equals(const State(Status.complete, Result.error)));
          expect(error, isRemoteException(
               "This test failed after it had already completed. Make sure to "
                   "use [expectAsync]\n"
               "or the [completes] matcher when testing async code."));
        }]);

        return liveTest.run();
      });
    });

    test("multiple asynchronous failures are reported", () {
      return _isolateTest(_multiFailTest).then((liveTest) {
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
    });
  });

  group("in a test with errors", () {
    test("an error reported causes the test to error", () {
      return _isolateTest(_errorTest).then((liveTest) {
        expectStates(liveTest, [
          const State(Status.running, Result.success),
          const State(Status.complete, Result.error)
        ]);

        expectErrors(liveTest, [(error) {
          expect(lastState.status, equals(Status.complete));
          expect(error, isRemoteException("oh no"));
        }]);

        return liveTest.run();
      });
    });

    test("an error reported asynchronously after the test causes it to error",
        () {
      return _isolateTest(_errorAfterSucceedTest).then((liveTest) {
        expectStates(liveTest, [
          const State(Status.running, Result.success),
          const State(Status.complete, Result.success),
          const State(Status.complete, Result.error)
        ]);

        expectErrors(liveTest, [(error) {
          expect(lastState,
              equals(const State(Status.complete, Result.error)));
          expect(error, isRemoteException("oh no"));
        }, (error) {
          expect(error, isRemoteException(
               "This test failed after it had already completed. Make sure to "
                   "use [expectAsync]\n"
               "or the [completes] matcher when testing async code."));
        }]);

        return liveTest.run();
      });
    });

    test("multiple asynchronous errors are reported", () {
      return _isolateTest(_multiErrorTest).then((liveTest) {
        expectStates(liveTest, [
          const State(Status.running, Result.success),
          const State(Status.complete, Result.error)
        ]);

        expectErrors(liveTest, [(error) {
          expect(lastState.status, equals(Status.complete));
          expect(error, isRemoteException("one"));
        }, (error) {
          expect(error, isRemoteException("two"));
        }, (error) {
          expect(error, isRemoteException("three"));
        }, (error) {
          expect(error, isRemoteException("four"));
        }]);

        return liveTest.run();
      });
    });
  });
}

/// Loads the first test defined in [entryPoint] in another isolate.
///
/// This test will be automatically closed when the test is finished.
Future<LiveTest> _isolateTest(void entryPoint(SendPort sendPort)) {
  return _spawnIsolate(entryPoint).then((receivePort) {
    return receivePort.first;
  }).then((response) {
    expect(response, containsPair("type", "success"));

    var testMap = response["tests"].first;
    var test = new IsolateTest(testMap["name"], testMap["sendPort"]);
    var suite = new Suite("suite", [test]);
    _liveTest = test.load(suite);
    return _liveTest;
  });
}

/// Spawns an isolate from [entryPoint], sends it a new [SendPort], and returns
/// the corresponding [ReceivePort].
///
/// This isolate will be automatically killed when the test is finished.
Future<ReceivePort> _spawnIsolate(void entryPoint(SendPort sendPort)) {
  var receivePort = new ReceivePort();
  return Isolate.spawn(entryPoint, receivePort.sendPort).then((isolate) {
    _isolate = isolate;
    return receivePort;
  });
}

/// An isolate entrypoint that throws immediately.
void _loadError(SendPort sendPort) =>
    VmListener.start(sendPort, () => () => throw 'oh no');

/// An isolate entrypoint that throws a NoSuchMethodError.
void _noSuchMethodError(SendPort sendPort) {
  return VmListener.start(sendPort, () =>
      throw new NoSuchMethodError(null, #main, [], {}));
}

/// An isolate entrypoint that returns a non-function.
void _nonFunction(SendPort sendPort) =>
    VmListener.start(sendPort, () => null);

/// An isolate entrypoint that returns a function with the wrong arity.
void _wrongArity(SendPort sendPort) =>
    VmListener.start(sendPort, () => (_) {});

/// An isolate entrypoint that defines three tests that succeed.
void _successfulTests(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("successful 1", () {});
    test("successful 2", () {});
    test("successful 3", () {});
  });
}

/// An isolate entrypoint that defines a test that fails.
void _failingTest(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("failure", () => throw new TestFailure('oh no'));
  });
}

/// An isolate entrypoint that defines a test that fails after succeeding.
void _failAfterSucceedTest(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("fail after succeed", () {
      pumpEventQueue().then((_) {
        throw new TestFailure('oh no');
      });
    });
  });
}

/// An isolate entrypoint that defines a test that fails multiple times.
void _multiFailTest(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("multiple failures", () {
      Invoker.current.addOutstandingCallback();
      new Future(() => throw new TestFailure("one"));
      new Future(() => throw new TestFailure("two"));
      new Future(() => throw new TestFailure("three"));
      new Future(() => throw new TestFailure("four"));
    });
  });
}

/// An isolate entrypoint that defines a test that errors.
void _errorTest(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("error", () => throw 'oh no');
  });
}

/// An isolate entrypoint that defines a test that errors after succeeding.
void _errorAfterSucceedTest(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("error after succeed", () {
      pumpEventQueue().then((_) => throw 'oh no');
    });
  });
}

/// An isolate entrypoint that defines a test that errors multiple times.
void _multiErrorTest(SendPort sendPort) {
  VmListener.start(sendPort, () => () {
    test("multiple errors", () {
      Invoker.current.addOutstandingCallback();
      new Future(() => throw "one");
      new Future(() => throw "two");
      new Future(() => throw "three");
      new Future(() => throw "four");
    });
  });
}
