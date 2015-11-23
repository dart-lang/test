// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:convert';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'package:test/src/runner/version.dart';

import '../io.dart';

/// The first event emitted by the JSON reporter.
final _start = {
  "type": "start",
  "protocolVersion": "0.1.0",
  "runnerVersion": testVersion
};

void main() {
  useSandbox();

  test("runs several successful tests and reports when each completes", () {
    _expectReport("""
      test('success 1', () {});
      test('success 2', () {});
      test('success 3', () {});
    """, [
      _start,
      _testStart(0, "loading test.dart"),
      _testDone(0, hidden: true),
      _testStart(1, "success 1"),
      _testDone(1),
      _testStart(2, "success 2"),
      _testDone(2),
      _testStart(3, "success 3"),
      _testDone(3),
      _done()
    ]);
  });

  test("runs several failing tests and reports when each fails", () {
    _expectReport("""
      test('failure 1', () => throw new TestFailure('oh no'));
      test('failure 2', () => throw new TestFailure('oh no'));
      test('failure 3', () => throw new TestFailure('oh no'));
    """, [
      _start,
      _testStart(0, "loading test.dart"),
      _testDone(0, hidden: true),
      _testStart(1, "failure 1"),
      _error(1, "oh no", isFailure: true),
      _testDone(1, result: "failure"),
      _testStart(2, "failure 2"),
      _error(2, "oh no", isFailure: true),
      _testDone(2, result: "failure"),
      _testStart(3, "failure 3"),
      _error(3, "oh no", isFailure: true),
      _testDone(3, result: "failure"),
      _done(success: false)
    ]);
  });

  test("includes the full stack trace with --verbose-trace", () {
    d.file("test.dart", """
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """).create();

    var test = runTest(["--verbose-trace", "test.dart"], reporter: "json");
    test.stdout.expect(consumeThrough(contains("dart:isolate-patch")));
    test.shouldExit(1);
  });

  test("runs failing tests along with successful tests", () {
    _expectReport("""
      test('failure 1', () => throw new TestFailure('oh no'));
      test('success 1', () {});
      test('failure 2', () => throw new TestFailure('oh no'));
      test('success 2', () {});
    """, [
      _start,
      _testStart(0, "loading test.dart"),
      _testDone(0, hidden: true),
      _testStart(1, "failure 1"),
      _error(1, "oh no", isFailure: true),
      _testDone(1, result: "failure"),
      _testStart(2, "success 1"),
      _testDone(2),
      _testStart(3, "failure 2"),
      _error(3, "oh no", isFailure: true),
      _testDone(3, result: "failure"),
      _testStart(4, "success 2"),
      _testDone(4),
      _done(success: false)
    ]);
  });

  test("gracefully handles multiple test failures in a row", () {
    _expectReport("""
      // This completer ensures that the test isolate isn't killed until all
      // errors have been thrown.
      var completer = new Completer();
      test('failures', () {
        new Future.microtask(() => throw 'first error');
        new Future.microtask(() => throw 'second error');
        new Future.microtask(() => throw 'third error');
        new Future.microtask(completer.complete);
      });
      test('wait', () => completer.future);
    """, [
      _start,
      _testStart(0, "loading test.dart"),
      _testDone(0, hidden: true),
      _testStart(1, "failures"),
      _error(1, "first error"),
      _error(1, "second error"),
      _error(1, "third error"),
      _testDone(1, result: "error"),
      _testStart(2, "wait"),
      _testDone(2),
      _done(success: false)
    ]);
  });

  test("gracefully handles a test failing after completion", () {
    _expectReport("""
      // These completers ensure that the first test won't fail until the second
      // one is running, and that the test isolate isn't killed until all errors
      // have been thrown.
      var waitStarted = new Completer();
      var testDone = new Completer();
      test('failure', () {
        waitStarted.future.then((_) {
          new Future.microtask(testDone.complete);
          throw 'oh no';
        });
      });
      test('wait', () {
        waitStarted.complete();
        return testDone.future;
      });
    """, [
      _start,
      _testStart(0, "loading test.dart"),
      _testDone(0, hidden: true),
      _testStart(1, "failure"),
      _testDone(1),
      _testStart(2, "wait"),
      _error(1, "oh no"),
      _error(1,
          "This test failed after it had already completed. Make sure to "
            "use [expectAsync]\n"
          "or the [completes] matcher when testing async code."),
      _testDone(2),
      _done(success: false)
    ]);
  });

  group("print:", () {
    test("handles multiple prints", () {
      _expectReport("""
        test('test', () {
          print("one");
          print("two");
          print("three");
          print("four");
        });
      """, [
        _start,
        _testStart(0, "loading test.dart"),
        _testDone(0, hidden: true),
        _testStart(1, 'test'),
        _print(1, "one"),
        _print(1, "two"),
        _print(1, "three"),
        _print(1, "four"),
        _testDone(1),
        _done()
      ]);
    });

    test("handles a print after the test completes", () {
      _expectReport("""
        // This completer ensures that the test isolate isn't killed until all
        // prints have happened.
        var testDone = new Completer();
        var waitStarted = new Completer();
        test('test', () async {
          waitStarted.future.then((_) {
            new Future(() => print("one"));
            new Future(() => print("two"));
            new Future(() => print("three"));
            new Future(() => print("four"));
            new Future(testDone.complete);
          });
        });

        test('wait', () {
          waitStarted.complete();
          return testDone.future;
        });
      """, [
        _start,
        _testStart(0, "loading test.dart"),
        _testDone(0, hidden: true),
        _testStart(1, 'test'),
        _testDone(1),
        _testStart(2, 'wait'),
        _print(1, "one"),
        _print(1, "two"),
        _print(1, "three"),
        _print(1, "four"),
        _testDone(2),
        _done()
      ]);
    });

    test("interleaves prints and errors", () {
      _expectReport("""
        // This completer ensures that the test isolate isn't killed until all
        // prints have happened.
        var completer = new Completer();
        test('test', () {
          scheduleMicrotask(() {
            print("three");
            print("four");
            throw "second error";
          });

          scheduleMicrotask(() {
            print("five");
            print("six");
            completer.complete();
          });

          print("one");
          print("two");
          throw "first error";
        });

        test('wait', () => completer.future);
      """, [
        _start,
        _testStart(0, "loading test.dart"),
        _testDone(0, hidden: true),
        _testStart(1, 'test'),
        _print(1, "one"),
        _print(1, "two"),
        _error(1, "first error"),
        _print(1, "three"),
        _print(1, "four"),
        _error(1, "second error"),
        _print(1, "five"),
        _print(1, "six"),
        _testDone(1, result: "error"),
        _testStart(2, 'wait'),
        _testDone(2),
        _done(success: false)
      ]);
    });
  });

  group("skip:", () {
    test("reports skipped tests", () {
      _expectReport("""
        test('skip 1', () {}, skip: true);
        test('skip 2', () {}, skip: true);
        test('skip 3', () {}, skip: true);
      """, [
        _start,
        _testStart(0, "loading test.dart"),
        _testDone(0, hidden: true),
        _testStart(1, "skip 1", skip: true),
        _testDone(1),
        _testStart(2, "skip 2", skip: true),
        _testDone(2),
        _testStart(3, "skip 3", skip: true),
        _testDone(3),
        _done()
      ]);
    });

    test("reports the skip reason if available", () {
      _expectReport("""
        test('skip 1', () {}, skip: 'some reason');
        test('skip 2', () {}, skip: 'or another');
      """, [
        _start,
        _testStart(0, "loading test.dart"),
        _testDone(0, hidden: true),
        _testStart(1, "skip 1", skip: "some reason"),
        _testDone(1),
        _testStart(2, "skip 2", skip: "or another"),
        _testDone(2),
        _done()
      ]);
    });
  });
}

/// Asserts that the tests defined by [tests] produce the JSON events in
/// [expected].
void _expectReport(String tests, List<Map> expected) {
  var dart = """
    import 'dart:async';

    import 'package:test/test.dart';

    void main() {
    $tests
    }
  """;

  d.file("test.dart", dart).create();

  var test = runTest(["test.dart"], reporter: "json");
  test.shouldExit();

  schedule(() async {
    var stdoutLines = await test.stdoutStream().toList();

    expect(stdoutLines.length, equals(expected.length),
        reason: "Expected $stdoutLines to match $expected.");

    // TODO(nweiz): validate each event against the JSON schema when
    // patefacio/json_schema#4 is merged.

    // Remove excess trailing whitespace.
    for (var i = 0; i < stdoutLines.length; i++) {
      var event = JSON.decode(stdoutLines[i]);
      expect(event.remove("time"), new isInstanceOf<int>());
      event.remove("stackTrace");
      expect(event, equals(expected[i]));
    }
  });
}

/// Returns the event emitted by the JSON reporter indicating that a test has
/// begun running.
///
/// If [skip] is `true`, the test is expected to be marked as skipped without a
/// reason. If it's a [String], the test is expected to be marked as skipped
/// with that reason.
Map _testStart(int id, String name, {skip}) {
  var metadata;
  if (skip == true) {
    metadata = {"skip": true, "skipReason": null};
  } else if (skip is String) {
    metadata = {"skip": true, "skipReason": skip};
  } else {
    metadata = {"skip": false, "skipReason": null};
  }

  return {
    "type": "testStart",
    "test": {"id": id, "name": name, "metadata": metadata}
  };
}

/// Returns the event emitted by the JSON reporter indicating that a test
/// printed [message].
Map _print(int id, String message) {
  return {
    "type": "print",
    "testID": id,
    "message": message
  };
}

/// Returns the event emitted by the JSON reporter indicating that a test
/// emitted [error].
///
/// The [isFailure] parameter indicates whether the error was a [TestFailure] or
/// not.
Map _error(int id, String error, {bool isFailure: false}) {
  return {
    "type": "error",
    "testID": id,
    "error": error,
    "isFailure": isFailure
  };
}

/// Returns the event emitted by the JSON reporter indicating that a test
/// finished.
///
/// The [result] parameter indicates the result of the test. It defaults to
/// `"success"`.
///
/// The [hidden] parameter indicates whether the test should not be displayed
/// after finishing.
Map _testDone(int id, {String result, bool hidden: false}) {
  result ??= "success";
  return {"type": "testDone", "testID": id, "result": result, "hidden": hidden};
}

Map _done({bool success: true}) => {"type": "done", "success": success};
