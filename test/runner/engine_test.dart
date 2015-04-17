// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/src/backend/declarer.dart';
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/suite.dart';
import 'package:test/src/runner/engine.dart';
import 'package:test/test.dart';

void main() {
  var declarer;
  setUp(() => declarer = new Declarer());

  test("runs each test in each suite in order", () {
    var testsRun = 0;
    for (var i = 0; i < 4; i++) {
      declarer.test("test ${i + 1}", expectAsync(() {
        expect(testsRun, equals(i));
        testsRun++;
      }, max: 1));
    }

    var engine = new Engine([
      new Suite(declarer.tests.take(2)),
      new Suite(declarer.tests.skip(2))
    ]);

    return engine.run().then((_) => expect(testsRun, equals(4)));
  });

  test("emits each test before it starts running and after the previous test "
      "finished", () {
    var testsRun = 0;
    for (var i = 0; i < 3; i++) {
      declarer.test("test ${i + 1}", expectAsync(() => testsRun++, max: 1));
    }

    var engine = new Engine([new Suite(declarer.tests)]);
    engine.onTestStarted.listen(expectAsync((liveTest) {
      // [testsRun] should be one less than the test currently running.
      expect(liveTest.test.name, equals("test ${testsRun + 1}"));

      // [Engine.onTestStarted] is guaranteed to fire before the first
      // [LiveTest.onStateChange].
      expect(liveTest.onStateChange.first,
          completion(equals(const State(Status.running, Result.success))));
    }, count: 3, max: 3));

    return engine.run();
  });

  test(".run() returns true if every test passes", () {
    for (var i = 0; i < 2; i++) {
      declarer.test("test ${i + 1}", () {});
    }

    var engine = new Engine([new Suite(declarer.tests)]);
    expect(engine.run(), completion(isTrue));
  });

  test(".run() returns false if any test fails", () {
    for (var i = 0; i < 2; i++) {
      declarer.test("test ${i + 1}", () {});
    }
    declarer.test("failure", () => throw new TestFailure("oh no"));

    var engine = new Engine([new Suite(declarer.tests)]);
    expect(engine.run(), completion(isFalse));
  });

  test(".run() returns false if any test errors", () {
    for (var i = 0; i < 2; i++) {
      declarer.test("test ${i + 1}", () {});
    }
    declarer.test("failure", () => throw "oh no");

    var engine = new Engine([new Suite(declarer.tests)]);
    expect(engine.run(), completion(isFalse));
  });

  test(".run() may not be called more than once", () {
    var engine = new Engine([]);
    expect(engine.run(), completes);
    expect(() => engine.run(), throwsStateError);
  });

  group("for a skipped test", () {
    test("doesn't run the test's body", () {
      var bodyRun = false;
      declarer.test("test", () => bodyRun = true, skip: true);

      var engine = new Engine([new Suite(declarer.tests)]);
      return engine.run().then((_) {
        expect(bodyRun, isFalse);
      });
    });

    test("exposes a LiveTest that emits the correct states", () {
      declarer.test("test", () {}, skip: true);

      var engine = new Engine([new Suite(declarer.tests)]);
      var liveTest = engine.liveTests.single;
      expect(liveTest.test, equals(declarer.tests.single));

      var first = true;
      liveTest.onStateChange.listen(expectAsync((state) {
        expect(state, equals(first
            ? const State(Status.running, Result.success)
            : const State(Status.complete, Result.success)));
        first = false;
      }, count: 2));

      expect(liveTest.onComplete, completes);

      return engine.run();
    });
  });
}
