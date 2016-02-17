// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
@Tags(const ["chrome"])

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/backend/state.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/runner/configuration.dart';
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
    _loader = new Loader(new Configuration(
            platforms: [TestPlatform.chrome],
            packageRoot: p.join(packageDir, 'packages')),
        root: _sandbox);
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
    setUp(() async {
      var suites = await _loader.loadFile(p.join(_sandbox, 'a_test.dart'))
          .toList();

      expect(suites, hasLength(1));
      var loadSuite = suites.first;
      suite = await loadSuite.getSuite();
    });

    test("returns a suite with the file path and platform", () {
      expect(suite.path, equals(p.join(_sandbox, 'a_test.dart')));
      expect(suite.platform, equals(TestPlatform.chrome));
    });

    test("returns tests with the correct names", () {
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


  test("loads tests that are defined asynchronously", () async {
    new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

Future main() {
  return new Future(() {
    test("success", () {});

    return new Future(() {
      test("failure", () => throw new TestFailure('oh no'));

      return new Future(() {
        test("error", () => throw 'oh no');
      });
    });
  });
}
""");

    var suites = await _loader.loadFile(p.join(_sandbox, 'a_test.dart'))
        .toList();
    expect(suites, hasLength(1));
    var loadSuite = suites.first;
    var suite = await loadSuite.getSuite();
    expect(suite.group.entries, hasLength(3));
    expect(suite.group.entries[0].name, equals("success"));
    expect(suite.group.entries[1].name, equals("failure"));
    expect(suite.group.entries[2].name, equals("error"));
  });

  test("loads a suite both in the browser and the VM", () async {
    var loader = new Loader(
        new Configuration(
            platforms: [TestPlatform.vm, TestPlatform.chrome],
            packageRoot: p.join(packageDir, 'packages')),
        root: _sandbox);
    var path = p.join(_sandbox, 'a_test.dart');

    try {
      var suites = await loader.loadFile(path)
          .asyncMap((loadSuite) => loadSuite.getSuite()).toList();
      expect(suites[0].platform, equals(TestPlatform.vm));
      expect(suites[0].path, equals(path));
      expect(suites[1].platform, equals(TestPlatform.chrome));
      expect(suites[1].path, equals(path));

      for (var suite in suites) {
        expect(suite.group.entries, hasLength(3));
        expect(suite.group.entries[0].name, equals("success"));
        expect(suite.group.entries[1].name, equals("failure"));
        expect(suite.group.entries[2].name, equals("error"));
      }
    } finally {
      await loader.close();
    }
  });

  test("a print in a loaded file is piped through the LoadSuite", () async {
    new File(p.join(_sandbox, 'a_test.dart')).writeAsStringSync("""
void main() {
  print('print within test');
}
""");
    var suites = await _loader.loadFile(p.join(_sandbox, 'a_test.dart'))
        .toList();
    expect(suites, hasLength(1));
    var loadSuite = suites.first;

    var liveTest = await loadSuite.group.entries.single.load(loadSuite);
    expect(liveTest.onPrint.first, completion(equals("print within test")));
    await liveTest.run();
    expectTestPassed(liveTest);
  });
}
