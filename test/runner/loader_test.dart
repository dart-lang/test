// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/test.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/runner/configuration/suite.dart';
import 'package:test/src/runner/loader.dart';
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

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
  setUp(() async {
    _sandbox = createTempDir();
    _loader = new Loader(root: _sandbox);
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
      var suites = await _loader
          .loadFile(p.join(_sandbox, 'a_test.dart'), SuiteConfiguration.empty)
          .toList();
      expect(suites, hasLength(1));
      var loadSuite = suites.first;
      suite = await loadSuite.getSuite();
    });

    test("returns a suite with the file path and platform", () {
      expect(suite.path, equals(p.join(_sandbox, 'a_test.dart')));
      expect(suite.platform, equals(TestPlatform.vm));
    });

    test("returns entries with the correct names and platforms", () {
      expect(suite.group.entries, hasLength(3));
      expect(suite.group.entries[0].name, equals("success"));
      expect(suite.group.entries[1].name, equals("failure"));
      expect(suite.group.entries[2].name, equals("error"));
    });

    test("can load and run a successful test", () {
      var liveTest = suite.group.entries[0].load(suite);

      expectStates(liveTest, [
        const State(Status.running, Result.success),
        const State(Status.complete, Result.success)
      ]);
      expectErrors(liveTest, []);

      return liveTest.run().whenComplete(() => liveTest.close());
    });

    test("can load and run a failing test", () {
      var liveTest = suite.group.entries[1].load(suite);
      expectSingleFailure(liveTest);
      return liveTest.run().whenComplete(() => liveTest.close());
    });
  });

  group(".loadDir()", () {
    test("ignores non-Dart files", () {
      new File(p.join(_sandbox, 'a_test.txt')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox, SuiteConfiguration.empty).toList(),
          completion(isEmpty));
    });

    test("ignores files in packages/ directories", () {
      var dir = p.join(_sandbox, 'packages');
      new Directory(dir).createSync();
      new File(p.join(dir, 'a_test.dart')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox, SuiteConfiguration.empty).toList(),
          completion(isEmpty));
    });

    test("ignores files that don't end in _test.dart", () {
      new File(p.join(_sandbox, 'test.dart')).writeAsStringSync(_tests);
      expect(_loader.loadDir(_sandbox, SuiteConfiguration.empty).toList(),
          completion(isEmpty));
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

        suites = await _loader.loadDir(_sandbox, SuiteConfiguration.empty)
            .asyncMap((loadSuite) => loadSuite.getSuite())
            .toList();
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
        var liveTest = suite.group.entries[1].load(suite);
        expectSingleFailure(liveTest);
        return liveTest.run().whenComplete(() => liveTest.close());
      });
    });
  });

  test("a print in a loaded file is piped through the LoadSuite", () async {
    new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync("""
void main() {
  print('print within test');
}
""");
    var suites = await _loader
        .loadFile(p.join(_sandbox, 'a_test.dart'), SuiteConfiguration.empty)
        .toList();
    expect(suites, hasLength(1));
    var loadSuite = suites.first;

    var liveTest = await (loadSuite.group.entries.single as Test)
        .load(loadSuite);
    expect(liveTest.onMessage.first.then((message) => message.text),
        completion(equals("print within test")));
    await liveTest.run();
    expectTestPassed(liveTest);
  });

  // TODO: Test load suites. Don't forget to test that prints in loaded files
  // are piped through the suite. Also for browser tests!
}
