// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:scheduled_test/descriptor.dart' as d;
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
      test.stdout.expect(tagWarnings(['a', 'b', 'c']));
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+4: All tests passed!")));
      test.shouldExit(0);
    });

    test("runs a test with only a specified tag", () {
      var test = runTest(["--tags=a", "test.dart"]);
      test.stdout.expect(tagWarnings(['b', 'c']));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("runs a test with a specified tag among others", () {
      var test = runTest(["--tags=c", "test.dart"]);
      test.stdout.expect(tagWarnings(['a', 'b']));
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("with multiple tags, runs only tests matching all of them", () {
      var test = runTest(["--tags=b,c", "test.dart"]);
      test.stdout.expect(tagWarnings(['a']));
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("prints no warnings when all tags are specified", () {
      var test = runTest(["--tags=a,b,c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains("No tests ran.")));
      test.shouldExit(0);
    });
  });

  group("--exclude-tags", () {
    test("dosn't run a test with only an excluded tag", () {
      var test = runTest(["--exclude-tags=a", "test.dart"]);
      test.stdout.expect(tagWarnings(['b', 'c']));
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains(": bc")));
      test.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      test.shouldExit(0);
    });

    test("doesn't run a test with an exluded tag among others", () {
      var test = runTest(["--exclude-tags=c", "test.dart"]);
      test.stdout.expect(tagWarnings(['a', 'b']));
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains(": b")));
      test.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      test.shouldExit(0);
    });

    test("allows unused tags", () {
      var test = runTest(["--exclude-tags=b,z", "test.dart"]);
      test.stdout.expect(tagWarnings(['a', 'c']));
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains(": a")));
      test.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      test.shouldExit(0);
    });

    test("prints no warnings when all tags are specified", () {
      var test = runTest(["--exclude-tags=a,b,c", "test.dart"]);
      test.stdout.expect(consumeThrough(contains(": no tags")));
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
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

  group("warning formatting", () {
    test("for multiple tags", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("foo", () {}, tags: ["a", "b"]);
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(lines(
          'Warning: Tags were used that weren\'t specified on the command '
            'line.\n'
          '  a was used in the test "foo"\n'
          '  b was used in the test "foo"')));
      test.shouldExit(0);
    });

    test("for multiple tests", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("foo", () {}, tags: "a");
          test("bar", () {}, tags: "a");
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(lines(
          'Warning: A tag was used that wasn\'t specified on the command '
            'line.\n'
          '  a was used in:\n'
          '    the test "foo"\n'
          '    the test "bar"')));
      test.shouldExit(0);
    });

    test("for groups", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          group("group", () {
            test("foo", () {});
            test("bar", () {});
          }, tags: "a");
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(lines(
          'Warning: A tag was used that wasn\'t specified on the command '
            'line.\n'
          '  a was used in the group "group"')));
      test.shouldExit(0);
    });

    test("for suites", () {
      d.file("test.dart", """
        @Tags(const ["a"])
        import 'package:test/test.dart';

        void main() {
          test("foo", () {});
          test("bar", () {});
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(lines(
          'Warning: A tag was used that wasn\'t specified on the command '
            'line.\n'
          '  a was used in the suite itself')));
      test.shouldExit(0);
    });

    test("doesn't double-print a tag warning", () {
      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("foo", () {}, tags: "a");
        }
      """).create();

      var test = runTest(["-p", "vm,content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough(lines(
          'Warning: A tag was used that wasn\'t specified on the command '
            'line.\n'
          '  a was used in the test "foo"')));
      test.stdout.expect(never(startsWith("Warning:")));
      test.shouldExit(0);
    });
  });
}

/// Returns a [StreamMatcher] that asserts that a test emits warnings for [tags]
/// in order.
StreamMatcher tagWarnings(List<String> tags) => inOrder(() sync* {
  yield consumeThrough(
      "Warning: ${tags.length == 1 ? 'A tag was' : 'Tags were'} used that "
        "${tags.length == 1 ? "wasn't" : "weren't"} specified on the command "
        "line.");

  for (var tag in tags) {
    yield consumeWhile(isNot(contains(" was used in")));
    yield consumeThrough(startsWith("  $tag was used in"));
  }

  // Consume until the end of the warning block, and assert that it has no
  // further tags than the ones we specified.
  yield consumeWhile(isNot(anyOf([contains(" was used in"), isEmpty])));
  yield isEmpty;
}());

/// Returns a [StreamMatcher] that matches the lines of [string] in order.
StreamMatcher lines(String string) => inOrder(string.split("\n"));
