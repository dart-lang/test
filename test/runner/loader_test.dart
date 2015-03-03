// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unittest/src/backend/state.dart';
import 'package:unittest/src/runner/loader.dart';
import 'package:unittest/unittest.dart';

import '../io.dart';
import '../utils.dart';

Loader _loader;
String _sandbox;

final _tests = """
import 'dart:async';

import 'package:unittest/unittest.dart';

void main() {
  test("success", () {});
  test("failure", () => throw new TestFailure('oh no'));
  test("error", () => throw 'oh no');
}
""";

void main() {
  setUp(() {
    _loader = new Loader(packageRoot: p.join(packageDir, 'packages'));
    _sandbox = Directory.systemTemp.createTempSync('unittest_').path;
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
    return _loader.close();
  });

  group(".loadFile()", () {
    var suite;
    setUp(() {
      /// TODO(nweiz): Use scheduled_test for this once it's compatible with
      /// this version of unittest.
      new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync(_tests);
      return _loader.loadFile(p.join(_sandbox, 'a_test.dart'))
          .then((suite_) => suite = suite_);
    });

    test("returns a suite with a name matching the file path", () {
      expect(suite.name, equals(p.join(_sandbox, 'a_test.dart')));
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

    test("throws a nice error if the package root doesn't exist", () {
      var loader = new Loader();
      expect(() => loader.loadFile(p.join(_sandbox, 'a_test.dart')),
          throwsA(isLoadException(
              "Directory ${p.join(_sandbox, 'packages')} does not exist.")));
    });
  });

  group(".loadDir()", () {
    test("ignores non-Dart files", () {
      new File(p.join(_sandbox, 'a_test.txt')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox), completion(isEmpty));
    });

    test("ignores files in packages/ directories", () {
      var dir = p.join(_sandbox, 'packages');
      new Directory(dir).createSync();
      new File(p.join(dir, 'a_test.dart')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox), completion(isEmpty));
    });

    test("ignores files that don't end in _test.dart", () {
      new File(p.join(_sandbox, 'test.dart')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox), completion(isEmpty));
    });

    group("with suites loaded from a directory", () {
      var suites;
      setUp(() {
        /// TODO(nweiz): Use scheduled_test for this once it's compatible with
        /// this version of unittest.
        new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync(_tests);
        new File(p.join(_sandbox, 'another_test.dart'))
            .writeAsStringSync(_tests);
        new Directory(p.join(_sandbox, 'dir')).createSync();
        new File(p.join(_sandbox, 'dir/sub_test.dart'))
            .writeAsStringSync(_tests);

        return _loader.loadDir(_sandbox).then((suites_) => suites = suites_);
      });

      test("names those suites after their files", () {
        expect(suites.map((suite) => suite.name), unorderedEquals([
          p.join(_sandbox, 'a_test.dart'),
          p.join(_sandbox, 'another_test.dart'),
          p.join(_sandbox, 'dir/sub_test.dart')
        ]));
      });

      test("can run tests in those suites", () {
        var suite = suites.firstWhere((suite) => suite.name.contains("a_test"));
        var liveTest = suite.tests[1].load(suite);
        expectSingleFailure(liveTest);
        return liveTest.run().whenComplete(() => liveTest.close());
      });
    });
  });
}
