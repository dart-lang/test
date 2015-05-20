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

import '../io.dart';
import '../utils.dart';

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
    _loader = new Loader([TestPlatform.vm],
        root: _sandbox,
        packageRoot: p.join(packageDir, 'packages'));
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
    return _loader.close();
  });

  group(".loadFile()", () {
    var suite;
    setUp(() async {
      /// TODO(nweiz): Use scheduled_test for this once it's compatible with
      /// this version of test.
      new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync(_tests);
      var suites = await _loader.loadFile(p.join(_sandbox, 'a_test.dart'))
          .toList();
      expect(suites, hasLength(1));
      suite = suites.first;
    });

    test("returns a suite with the file path and platform", () {
      expect(suite.path, equals(p.join(_sandbox, 'a_test.dart')));
      expect(suite.platform, equals('VM'));
    });

    test("returns tests with the correct names and platforms", () {
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
      expect(() => new Loader([TestPlatform.chrome], root: _sandbox),
          throwsA(isApplicationException(
              "Directory ${p.prettyUri(p.toUri(p.join(_sandbox, 'packages')))} "
                  "does not exist.")));
    });
  });

  group(".loadDir()", () {
    test("ignores non-Dart files", () {
      new File(p.join(_sandbox, 'a_test.txt')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox).toList(), completion(isEmpty));
    });

    test("ignores files in packages/ directories", () {
      var dir = p.join(_sandbox, 'packages');
      new Directory(dir).createSync();
      new File(p.join(dir, 'a_test.dart')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox).toList(), completion(isEmpty));
    });

    test("ignores files that don't end in _test.dart", () {
      new File(p.join(_sandbox, 'test.dart')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox).toList(), completion(isEmpty));
    });

    group("with suites loaded from a directory", () {
      var suites;
      setUp(() async {
        /// TODO(nweiz): Use scheduled_test for this once it's compatible with
        /// this version of test.
        new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync(_tests);
        new File(p.join(_sandbox, 'another_test.dart'))
            .writeAsStringSync(_tests);
        new Directory(p.join(_sandbox, 'dir')).createSync();
        new File(p.join(_sandbox, 'dir/sub_test.dart'))
            .writeAsStringSync(_tests);

        suites = await _loader.loadDir(_sandbox).toList();
      });

      test("gives those suites the correct paths", () {
        expect(suites.map((suite) => suite.path), unorderedEquals([
          p.join(_sandbox, 'a_test.dart'),
          p.join(_sandbox, 'another_test.dart'),
          p.join(_sandbox, 'dir', 'sub_test.dart')
        ]));
      });

      test("can run tests in those suites", () {
        var suite = suites.firstWhere((suite) => suite.path.contains("a_test"));
        var liveTest = suite.tests[1].load(suite);
        expectSingleFailure(liveTest);
        return liveTest.run().whenComplete(() => liveTest.close());
      });
    });
  });
}
