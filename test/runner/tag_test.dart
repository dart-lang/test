// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

void main() {
  useSandbox();

  setUp(() {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("no tags", () {});
        test("a", () {}, tags: "a");
        test("b", () {}, tags: "b");
        test("bc", () {}, tags: ["b", "c"]);
      }
    """).create();
  });

  group("--tags", () {
    test("runs all tests when no tags are specified", () {
      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+4: All tests passed!")));
      expectTagWarnings(test, [
        ['a', 'a'],
        ['b', 'b'],
        ['b and c', 'bc']
      ]);
      test.shouldExit(0);
    });

    test("runs a test with only a specified tag", () {
      var test = runTest(["--tags=a", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings(test, [
        ['b', 'b'],
        ['b and c', 'bc']
      ]);
      test.shouldExit(0);
    });

    test("runs a test with a specified tag among others", () {
      var test = runTest(["--tags=c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings(test, [
        ['a', 'a'],
        ['b', 'b'],
        ['b', 'bc']
      ]);
      test.shouldExit(0);
    });

    test("with multiple tags, runs only tests matching all of them", () {
      var test = runTest(["--tags=b,c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings(test, [
        ['a', 'a']
      ]);
      test.shouldExit(0);
    });

    test("prints no warnings when all tags are specified", () {
      var test = runTest(["--tags=a,b,c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      expectTagWarnings(test, []);
      test.shouldExit(0);
    });
  });

  group("--exclude-tags", () {
    test("dosn't run a test with only an excluded tag", () {
      var test = runTest(["--exclude-tags=a", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      expectTagWarnings(test, [
        ['b', 'b'],
        ['b and c', 'bc'],
      ]);
      test.shouldExit(0);
    });

    test("doesn't run a test with an exluded tag among others", () {
      var test = runTest(["--exclude-tags=c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      expectTagWarnings(test, [
        ['a', 'a'],
        ['b', 'b'],
        ['b', 'bc'],
      ]);
      test.shouldExit(0);
    });

    test("allows unused tags", () {
      var test = runTest(["--exclude-tags=b,z", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      expectTagWarnings(test, [
        ['a', 'a'],
        ['c', 'bc'],
      ]);
      test.shouldExit(0);
    });

    test("prints no warnings when all tags are specified", () {
      var test = runTest(["--exclude-tags=a,b,c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings(test, []);
      test.shouldExit(0);
    });
  });

  group("with a tagged group", () {
    setUp(() {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          group("a", () {
            test("in", () {});
          }, tags: "a");

          test("out", () {});
        }
      """).create();
    });

    test("includes tags specified on the group", () {
      var test = runTest(["-x", "a", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": out")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("excludes tags specified on the group", () {
      var test = runTest(["-t", "a", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": a in")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });
  });

  group('with --tags and --exclude-tags', () {
    test('refuses to include and exclude the same tag simultaneously', () {
      var test = runTest(["-t", "a,b", "-x", "a,b,c", "test.dart"]);
      test.stderr.expect(consumeThrough(
          contains("The tags a and b were both included and excluded.")));
      test.shouldExit(64);
    });

    test("--exclude-tags takes precedence over --tags", () {
      var test = runTest(["-t", "b", "-x", "c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });
  });

  test('respects top-level @Tags annotations', () {
    d.file("test.dart", """
      @Tags(const ['a'])
      import 'package:test/test.dart';

      void main() {
        test("foo", () {});
      }
    """).create();

    var test = runTest(["-x", "a", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("No tests ran")));
    test.shouldExit(0);
  });
}

/// Asserts that [test] emits [warnings] in order.
///
/// Each element of [warnings] should be a pair whose first element is the
/// unrecognized tags and whose second is the name of the test in which they
/// were detected.
expectTagWarnings(ScheduledProcess test, List<List<String>> warnings) {
  for (var warning in warnings) {
    test.stderr.expect(consumeThrough(allOf([
      startsWith("Warning: Unknown tag"),
      endsWith('${warning.first} in test "${warning.last}".')
    ])));
  }
  test.stderr.expect(never(startsWith("Warning:")));
}
