// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/src/declarer.dart';
import 'package:unittest/src/engine.dart';
import 'package:unittest/src/state.dart';
import 'package:unittest/src/suite.dart';
import 'package:unittest/unittest.dart';

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
      new Suite("suite 1", declarer.tests.take(2)),
      new Suite("suite 2", declarer.tests.skip(2))
    ]);

    return engine.run().then((_) => expect(testsRun, equals(4)));
  });

  test("emits each test before it starts running and after the previous test "
      "finished", () {
    var testsRun = 0;
    for (var i = 0; i < 3; i++) {
      declarer.test("test ${i + 1}", expectAsync(() => testsRun++, max: 1));
    }

    var engine = new Engine([new Suite("suite", declarer.tests)]);
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

    var engine = new Engine([new Suite("suite", declarer.tests)]);
    expect(engine.run(), completion(isTrue));
  });

  test(".run() returns false if any test fails", () {
    for (var i = 0; i < 2; i++) {
      declarer.test("test ${i + 1}", () {});
    }
    declarer.test("failure", () => throw new TestFailure("oh no"));

    var engine = new Engine([new Suite("suite", declarer.tests)]);
    expect(engine.run(), completion(isFalse));
  });

  test(".run() returns false if any test errors", () {
    for (var i = 0; i < 2; i++) {
      declarer.test("test ${i + 1}", () {});
    }
    declarer.test("failure", () => throw "oh no");

    var engine = new Engine([new Suite("suite", declarer.tests)]);
    expect(engine.run(), completion(isFalse));
  });

  test(".run() may not be called more than once", () {
    var engine = new Engine([]);
    expect(engine.run(), completes);
    expect(() => engine.run(), throwsStateError);
  });
}
