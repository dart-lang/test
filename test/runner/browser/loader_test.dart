// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/runner/loader.dart';
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../../io.dart';
import '../../utils.dart';

Loader _loader;
String _sandbox;

final _tests = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
  test("failure", () => throw new TestFailure('oh no'));
  test("error", () => throw 'oh no');
}
""";

void main() {
  setUp(() {
    _sandbox = createTempDir();
    _loader = new Loader([TestPlatform.chrome],
        root: _sandbox,
        packageRoot: p.join(packageDir, 'packages'));
    /// TODO(nweiz): Use scheduled_test for this once it's compatible with this
    /// version of test.
    new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync(_tests);
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
    return _loader.close();
  });

  group(".loadFile()", () {
    var suite;
    setUp(() {
      return _loader.loadFile(p.join(_sandbox, 'a_test.dart')).toList()
          .then((suites) {
        expect(suites, hasLength(1));
        suite = suites.first;
      });
    });

    test("returns a suite with the file path and platform", () {
      expect(suite.path, equals(p.join(_sandbox, 'a_test.dart')));
      expect(suite.platform, equals('Chrome'));
    });

    test("returns tests with the correct names", () {
      expect(suite.tests, hasLength(3));
      expect(suite.tests[0].name, equals("success"));
      expect(suite.tests[1].name, equals("failure"));
      expect(suite.tests[2].name, equals("error"));
    });

    test("can load and run a successful test", () {
      var liveTest = suite.tests[0].load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.success)
      ]);
      expectErrors(liveTest, []);

      return liveTest.run().whenComplete(() => liveTest.close());
    });

    test("can load and run a failing test", () {
      var liveTest = suite.tests[1].load(suite);
      expectSingleFailure(liveTest);
      return liveTest.run().whenComplete(() => liveTest.close());
    });
  });

  test("loads a suite both in the browser and the VM", () {
    var loader = new Loader([TestPlatform.vm, TestPlatform.chrome],
        root: _sandbox,
        packageRoot: p.join(packageDir, 'packages'));
    var path = p.join(_sandbox, 'a_test.dart');
    return loader.loadFile(path).toList().then((suites) {
      expect(suites[0].platform, equals('VM'));
      expect(suites[0].path, equals(path));
      expect(suites[1].platform, equals('Chrome'));
      expect(suites[1].path, equals(path));

      for (var suite in suites) {
        expect(suite.tests, hasLength(3));
        expect(suite.tests[0].name, equals("success"));
        expect(suite.tests[1].name, equals("failure"));
        expect(suite.tests[2].name, equals("error"));
      }
    }).whenComplete(loader.close);
  });
}
