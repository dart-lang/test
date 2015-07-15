// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';

import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/suite.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/runner/load_exception.dart';
import 'package:test/src/runner/load_suite.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  test("running a load test causes LoadSuite.suite to emit a suite", () async {
    var innerSuite = new Suite([]);
    var suite = new LoadSuite("name", () => new Future.value(innerSuite));
    expect(suite.tests, hasLength(1));

    expect(suite.suite, completion(equals(innerSuite)));
    var liveTest = await suite.tests.single.load(suite);
    await liveTest.run();
    expectTestPassed(liveTest);
  });

  test("running a load suite's body may be synchronous", () async {
    var innerSuite = new Suite([]);
    var suite = new LoadSuite("name", () => innerSuite);
    expect(suite.tests, hasLength(1));

    expect(suite.suite, completion(equals(innerSuite)));
    var liveTest = await suite.tests.single.load(suite);
    await liveTest.run();
    expectTestPassed(liveTest);
  });

  test("a load test doesn't complete until the body returns", () async {
    var completer = new Completer();
    var suite = new LoadSuite("name", () => completer.future);
    expect(suite.tests, hasLength(1));

    var liveTest = await suite.tests.single.load(suite);
    expect(liveTest.run(), completes);
    await new Future.delayed(Duration.ZERO);
    expect(liveTest.state.status, equals(Status.running));

    completer.complete(new Suite([]));
    await new Future.delayed(Duration.ZERO);
    expectTestPassed(liveTest);
  });

  test("a load test forwards errors and completes LoadSuite.suite to null",
      () async {
    var suite = new LoadSuite("name", () => fail("error"));
    expect(suite.tests, hasLength(1));

    expect(suite.suite, completion(isNull));

    var liveTest = await suite.tests.single.load(suite);
    await liveTest.run();
    expectTestFailed(liveTest, "error");
  });

  test("a load test completes early if it's closed", () async {
    var suite = new LoadSuite("name", () => new Completer().future);
    expect(suite.tests, hasLength(1));

    var liveTest = await suite.tests.single.load(suite);
    expect(liveTest.run(), completes);
    await new Future.delayed(Duration.ZERO);
    expect(liveTest.state.status, equals(Status.running));

    expect(liveTest.close(), completes);
  });

  test("forLoadException() creates a suite that completes to a LoadException",
      () async {
    var exception = new LoadException("path", "error");
    var suite = new LoadSuite.forLoadException(exception);
    expect(suite.tests, hasLength(1));

    expect(suite.suite, completion(isNull));

    var liveTest = await suite.tests.single.load(suite);
    await liveTest.run();
    expect(liveTest.state.status, equals(Status.complete));
    expect(liveTest.state.result, equals(Result.error));
    expect(liveTest.errors, hasLength(1));
    expect(liveTest.errors.first.error, equals(exception));
  });

  test("forSuite() creates a load suite that completes to a test suite",
      () async {
    var innerSuite = new Suite([]);
    var suite = new LoadSuite.forSuite(innerSuite);
    expect(suite.tests, hasLength(1));

    expect(suite.suite, completion(equals(innerSuite)));
    var liveTest = await suite.tests.single.load(suite);
    await liveTest.run();
    expectTestPassed(liveTest);
  });

  group("changeSuite()", () {
    test("returns a new load suite with the same properties", () {
      var innerSuite = new Suite([]);
      var suite = new LoadSuite("name", () => innerSuite,
          platform: TestPlatform.vm);
      expect(suite.tests, hasLength(1));

      var newSuite = suite.changeSuite((suite) => suite);
      expect(newSuite.platform, equals(TestPlatform.vm));
      expect(newSuite.tests, equals(suite.tests));
    });

    test("changes the inner suite", () async {
      var innerSuite = new Suite([]);
      var suite = new LoadSuite("name", () => innerSuite);
      expect(suite.tests, hasLength(1));

      var newInnerSuite = new Suite([]);
      var newSuite = suite.changeSuite((suite) => newInnerSuite);
      expect(newSuite.suite, completion(equals(newInnerSuite)));

      var liveTest = await suite.tests.single.load(suite);
      await liveTest.run();
      expectTestPassed(liveTest);
    });

    test("doesn't run change() if the suite is null", () async {
      var suite = new LoadSuite("name", () => null);
      expect(suite.tests, hasLength(1));

      var newSuite = suite.changeSuite(expectAsync((_) {}, count: 0));
      expect(newSuite.suite, completion(isNull));

      var liveTest = await suite.tests.single.load(suite);
      await liveTest.run();
      expectTestPassed(liveTest);
    });
  });

  group("getSuite()", () {
    test("runs the test and returns the suite", () {
      var innerSuite = new Suite([]);
      var suite = new LoadSuite.forSuite(innerSuite);
      expect(suite.tests, hasLength(1));

      expect(suite.getSuite(), completion(equals(innerSuite)));
    });

    test("forwards errors to the future", () {
      var suite = new LoadSuite("name", () => throw "error");
      expect(suite.tests, hasLength(1));

      expect(suite.getSuite(), throwsA("error"));
    });
  });
}
