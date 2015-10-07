// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/src/backend/group.dart';
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/test.dart';
import 'package:test/src/runner/engine.dart';
import 'package:test/src/runner/runner_suite.dart';
import 'package:test/src/runner/vm/environment.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  test("runs each test in each suite in order", () async {
    var testsRun = 0;
    var tests = declare(() {
      for (var i = 0; i < 4; i++) {
        test("test ${i + 1}", expectAsync(() {
          expect(testsRun, equals(i));
          testsRun++;
        }, max: 1));
      }
    });

    var engine = new Engine.withSuites([
      new RunnerSuite(const VMEnvironment(), new Group.root(tests.take(2))),
      new RunnerSuite(const VMEnvironment(), new Group.root(tests.skip(2)))
    ]);

    await engine.run();
    expect(testsRun, equals(4));
  });

  test("runs tests in a suite added after run() was called", () {
    var testsRun = 0;
    var tests = declare(() {
      for (var i = 0; i < 4; i++) {
        test("test ${i + 1}", expectAsync(() {
          expect(testsRun, equals(i));
          testsRun++;
        }, max: 1));
      }
    });

    var engine = new Engine();
    expect(engine.run().then((_) {
      expect(testsRun, equals(4));
    }), completes);

    engine.suiteSink.add(
        new RunnerSuite(const VMEnvironment(), new Group.root(tests)));
    engine.suiteSink.close();
  });

  test("emits each test before it starts running and after the previous test "
      "finished", () {
    var testsRun = 0;
    var engine = withTests(declare(() {
      for (var i = 0; i < 3; i++) {
        test("test ${i + 1}", expectAsync(() => testsRun++, max: 1));
      }
    }));

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
    var engine = withTests(declare(() {
      for (var i = 0; i < 2; i++) {
        test("test ${i + 1}", () {});
      }
    }));

    expect(engine.run(), completion(isTrue));
  });

  test(".run() returns false if any test fails", () {
    var engine = withTests(declare(() {
      for (var i = 0; i < 2; i++) {
        test("test ${i + 1}", () {});
      }
      test("failure", () => throw new TestFailure("oh no"));
    }));

    expect(engine.run(), completion(isFalse));
  });

  test(".run() returns false if any test errors", () {
    var engine = withTests(declare(() {
      for (var i = 0; i < 2; i++) {
        test("test ${i + 1}", () {});
      }
      test("failure", () => throw "oh no");
    }));

    expect(engine.run(), completion(isFalse));
  });

  test(".run() may not be called more than once", () {
    var engine = new Engine.withSuites([]);
    expect(engine.run(), completes);
    expect(engine.run, throwsStateError);
  });

  group("for a skipped test", () {
    test("doesn't run the test's body", () async {
      var bodyRun = false;
      var engine = withTests(declare(() {
        test("test", () => bodyRun = true, skip: true);
      }));

      await engine.run();
      expect(bodyRun, isFalse);
    });

    test("exposes a LiveTest that emits the correct states", () {
      var tests = declare(() {
        test("test", () {}, skip: true);
      });

      var engine = withTests(tests);

      engine.onTestStarted.listen(expectAsync((liveTest) {
        expect(liveTest, same(engine.liveTests.single));
        expect(liveTest.test.name, equals(tests.single.name));

        var first = true;
        liveTest.onStateChange.listen(expectAsync((state) {
          expect(state, equals(first
              ? const State(Status.running, Result.success)
              : const State(Status.complete, Result.success)));
          first = false;
        }, count: 2));

        expect(liveTest.onComplete, completes);
      }));

      return engine.run();
    });
  });
}

/// Returns an engine that will run [tests].
Engine withTests(List<Test> tests) {
  return new Engine.withSuites([
    new RunnerSuite(const VMEnvironment(), new Group.root(tests))
  ]);
}
