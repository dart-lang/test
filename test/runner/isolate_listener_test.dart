// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';
import 'dart:isolate';

import 'package:test/src/backend/group.dart';
import 'package:test/src/backend/invoker.dart';
import 'package:test/src/backend/live_test.dart';
import 'package:test/src/backend/metadata.dart';
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/suite.dart';
import 'package:test/src/runner/vm/isolate_listener.dart';
import 'package:test/src/runner/vm/isolate_test.dart';
import 'package:test/src/util/remote_exception.dart';
import 'package:test/test.dart';

import '../utils.dart';

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
    if (_isolate != null) _isolate.kill();
    _isolate = null;

    if (_liveTest != null) _liveTest.close();
    _liveTest = null;
  });

  test("sends a list of available tests and groups on startup", () async {
    var response = await (await _spawnIsolate(_successfulTests)).first;
    expect(response, containsPair("type", "success"));
    expect(response, contains("root"));

    var root = response["root"];
    expect(root, containsPair("type", "group"));
    expect(root, containsPair("name", null));

    var tests = root["entries"];
    expect(tests, hasLength(3));
    expect(tests[0], containsPair("name", "successful 1"));
    expect(tests[1], containsPair("name", "successful 2"));
    expect(tests[2], containsPair("type", "group"));
    expect(tests[2], containsPair("name", "successful"));
    expect(tests[2], contains("entries"));
    expect(tests[2]["entries"][0], containsPair("name", "successful 3"));
  });

  test("waits for a returned future sending a response", () async {
    var response = await (await _spawnIsolate(_asyncTests)).first;
    expect(response, containsPair("type", "success"));
    expect(response, contains("root"));

    var tests = response["root"]["entries"];
    expect(tests, hasLength(3));
    expect(tests[0], containsPair("name", "successful 1"));
    expect(tests[1], containsPair("name", "successful 2"));
    expect(tests[2], containsPair("name", "successful 3"));
  });

  test("sends an error response if loading fails", () async {
    var response = await (await _spawnIsolate(_loadError)).first;
    expect(response, containsPair("type", "error"));
    expect(response, contains("error"));

    var error = RemoteException.deserialize(response["error"]).error;
    expect(error.message, equals("oh no"));
    expect(error.type, equals("String"));
  });

  test("sends an error response on a NoSuchMethodError", () async {
    var response = await (await _spawnIsolate(_noSuchMethodError)).first;
    expect(response, containsPair("type", "loadException"));
    expect(response,
        containsPair("message", "No top-level main() function defined."));
  });

  test("sends an error response on non-function main", () async {
    var response = await (await _spawnIsolate(_nonFunction)).first;
    expect(response, containsPair("type", "loadException"));
    expect(response,
        containsPair("message", "Top-level main getter is not a function."));
  });

  test("sends an error response on wrong-arity main", () async {
    var response = await (await _spawnIsolate(_wrongArity)).first;
    expect(response, containsPair("type", "loadException"));
    expect(
        response,
        containsPair(
            "message",
            "Top-level main() function takes arguments."));
  });

  group("in a successful test", () {
    test("the state changes from pending to running to complete", () async {
      var liveTest = await _isolateTest(_successfulTests);
      liveTest.onError.listen(expectAsync((_) {}, count: 0));

      expect(liveTest.state,
          equals(const State(Status.pending, Result.success)));

      var future = liveTest.run();
      expect(liveTest.state,
          equals(const State(Status.running, Result.success)));

      await future;
      expect(liveTest.state,
          equals(const State(Status.complete, Result.success)));
    });

    test("onStateChange fires for each state change", () async {
      var liveTest = await _isolateTest(_successfulTests);
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

      await liveTest.run();
    });
  });

  group("in a test with failures", () {
    test("a failure reported causes the test to fail", () async {
      var liveTest = await _isolateTest(_failingTest);
      expectSingleFailure(liveTest);
      await liveTest.run();
    });

    test("a failure reported asynchronously after the test causes it to error",
        () async {
      var liveTest = await _isolateTest(_failAfterSucceedTest);
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

      await liveTest.run();
    });

    test("multiple asynchronous failures are reported", () async {
      var liveTest = await _isolateTest(_multiFailTest);
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

      await liveTest.run();
    });
  });

  group("in a test with errors", () {
    test("an error reported causes the test to error", () async {
      var liveTest = await _isolateTest(_errorTest);
      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.error)
      ]);

      expectErrors(liveTest, [(error) {
        expect(lastState.status, equals(Status.complete));
        expect(error, isRemoteException("oh no"));
      }]);

      await liveTest.run();
    });

    test("an error reported asynchronously after the test causes it to error",
        () async {
      var liveTest = await _isolateTest(_errorAfterSucceedTest);
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

      await liveTest.run();
    });

    test("multiple asynchronous errors are reported", () async {
      var liveTest = await _isolateTest(_multiErrorTest);
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

      await liveTest.run();
    });
  });

  test("forwards a test's prints", () async {
    var liveTest = await _isolateTest(_printTest);
    expect(liveTest.onPrint.take(2).toList(),
        completion(equals(["Hello,", "world!"])));

    await liveTest.run();
  });
}

/// Loads the first test defined in [entryPoint] in another isolate.
///
/// This test will be automatically closed when the test is finished.
Future<LiveTest> _isolateTest(void entryPoint(SendPort sendPort)) async {
  var response = await (await _spawnIsolate(entryPoint)).first;
  expect(response, containsPair("type", "success"));

  var testMap = response["root"]["entries"].first;
  expect(testMap, containsPair("type", "test"));
  var metadata = new Metadata.deserialize(testMap["metadata"]);
  var test = new IsolateTest(testMap["name"], metadata, testMap["sendPort"]);
  var suite = new Suite(new Group.root([test]));
  _liveTest = test.load(suite);
  return _liveTest;
}

/// Spawns an isolate from [entryPoint], sends it a new [SendPort], and returns
/// the corresponding [ReceivePort].
///
/// This isolate will be automatically killed when the test is finished.
Future<ReceivePort> _spawnIsolate(void entryPoint(SendPort sendPort)) async {
  var receivePort = new ReceivePort();
  var isolate = await Isolate.spawn(entryPoint, receivePort.sendPort);
  _isolate = isolate;
  return receivePort;
}

/// An isolate entrypoint that throws immediately.
void _loadError(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () => throw 'oh no');
}

/// An isolate entrypoint that throws a NoSuchMethodError.
void _noSuchMethodError(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () =>
      throw new NoSuchMethodError(null, #main, [], {}));
}

/// An isolate entrypoint that returns a non-function.
void _nonFunction(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => null);
}

/// An isolate entrypoint that returns a function with the wrong arity.
void _wrongArity(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => (_) {});
}

/// An isolate entrypoint that defines three tests that succeed.
void _successfulTests(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("successful 1", () {});
    test("successful 2", () {});
    group("successful", () => test("3", () {}));
  });
}

/// An isolate entrypoint that defines three tests asynchronously.
void _asyncTests(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    return new Future(() {
      test("successful 1", () {});

      return new Future(() {
        test("successful 2", () {});

        return new Future(() {
          test("successful 3", () {});
        });
      });
    });
  });
}

/// An isolate entrypoint that defines a test that fails.
void _failingTest(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("failure", () => throw new TestFailure('oh no'));
  });
}

/// An isolate entrypoint that defines a test that fails after succeeding.
void _failAfterSucceedTest(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("fail after succeed", () {
      pumpEventQueue().then((_) {
        throw new TestFailure('oh no');
      });
    });
  });
}

/// An isolate entrypoint that defines a test that fails multiple times.
void _multiFailTest(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
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
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("error", () => throw 'oh no');
  });
}

/// An isolate entrypoint that defines a test that errors after succeeding.
void _errorAfterSucceedTest(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("error after succeed", () {
      pumpEventQueue().then((_) {
        throw 'oh no';
      });
    });
  });
}

/// An isolate entrypoint that defines a test that errors multiple times.
void _multiErrorTest(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("multiple errors", () {
      Invoker.current.addOutstandingCallback();
      new Future(() => throw "one");
      new Future(() => throw "two");
      new Future(() => throw "three");
      new Future(() => throw "four");
    });
  });
}

/// An isolate entrypoint that defines a test that prints twice.
void _printTest(SendPort sendPort) {
  IsolateListener.start(sendPort, new Metadata(), () => () {
    test("prints", () {
      print("Hello,");
      return new Future(() => print("world!"));
    });
  });
}

