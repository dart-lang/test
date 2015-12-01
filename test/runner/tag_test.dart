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

  var testRun;

  /// [warnings] contains pairs, each containing a comma-separated list of
  /// tags the warning is about and the test name.
  expectTagWarnings(List<List<String>> warnings) {
    for (var warning in warnings) {
      testRun.stderr.expect(consumeThrough(contains(
          "WARNING: unrecognized tags {${warning[0]}}"
              " in test '${warning[1]}'")));
    }
    testRun.stderr.expect(isDone);
  }

  group("--tags", () {
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

    test("runs all tests when no tags are specified", () {
      testRun = runTest(["test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+4: All tests passed!")));
      expectTagWarnings([
        ['a', 'a'],
        ['b', 'b'],
        ['b, c', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("runs only tests containing specified tags", () {
      testRun = runTest(["--tags=a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings([
        ['b', 'b'],
        ['b, c', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("runs tests with tags intersecting command-line tags", () {
      testRun = runTest(["--tags=c", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings([
        ['a', 'a'],
        ['b', 'b'],
        ['b', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("ignores tag set difference", () {
      testRun = runTest(["--tags=b,z", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      expectTagWarnings([
        ['a', 'a'],
        ['c', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("prints no warnings when all tags are specified", () {
      testRun = runTest(["--tags=a,b,c", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      expectTagWarnings([]);
      testRun.shouldExit(0);
    });
  });

  group("--tag aliases", () {
    setUp(() {
      d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  test("no tags", () {});
  test("a", () {}, tags: "a");
}
""").create();
    });

    test("takes -t abbreviation", () {
      testRun = runTest(["-t", "a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      testRun.shouldExit(0);
    });

    test("takes --tag typo", () {
      testRun = runTest(["--tag=a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      testRun.shouldExit(0);
    });
  });

  group("--exclude-tags", () {
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

    test("excludes tests containing excluded tags", () {
      testRun = runTest(["--exclude-tags=a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      expectTagWarnings([
        ['b', 'b'],
        ['b, c', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("ignores tag set difference", () {
      testRun = runTest(["--exclude-tags=b,z", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+2: All tests passed!")));
      expectTagWarnings([
        ['a', 'a'],
        ['c', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("excludes tests that intersect excluded tags", () {
      testRun = runTest(["--exclude-tags=c", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+3: All tests passed!")));
      expectTagWarnings([
        ['a', 'a'],
        ['b', 'b'],
        ['b', 'bc'],
      ]);
      testRun.shouldExit(0);
    });

    test("prints no warnings when all tags are specified", () {
      testRun = runTest(["--exclude-tags=a,b,c", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      expectTagWarnings([]);
      testRun.shouldExit(0);
    });
  });

  group("tagged groups", () {
    setUp(() {
      d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  group("a", () {
    test("foo", () {});
  }, tags: "a");
}
""").create();
    });

    test("excludes tags specified on the group", () {
      testRun = runTest(["-x", "a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("No tests ran")));
      testRun.shouldExit(0);
    });
  });

  group("--exclude-tags aliases", () {
    setUp(() {
      d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  test("no tags", () {});
  test("a", () {}, tags: "a");
}
""").create();
    });

    test("takes -x abbreviation", () {
      testRun = runTest(["-x", "a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      testRun.shouldExit(0);
    });

    test("takes --exclude-tag typo", () {
      testRun = runTest(["--exclude-tag=a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      testRun.shouldExit(0);
    });
  });

  group('interaction between --tags and --exclude-tags', () {
    test('refuses include and exclude the same tag simultaneously', () {
      d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  test("foo", () {});
}
""").create();

      testRun = runTest(["-t", "a,b", "-x", "a,b,c", "test.dart"]);
      testRun.stderr.expect(consumeThrough(
          contains("Included and excluded tag sets may not intersect. "
              "Found intersection: a, b")));
      testRun.stderr.expect(consumeThrough(contains("Usage:")));
      testRun.shouldExit(64);
    });

    test("--exclude-tags takes precedence over --tags", () {
      d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  test("ab", () {}, tags: ["a", "b"]);
}
""").create();

      testRun = runTest(["-t", "a", "-x", "b", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("No tests ran")));
      testRun.shouldExit(0);
    });
  });

  group('@Tags annotation', () {
    test('applies tags to the suite', () {
      d.file("test.dart", """
@Tags(const ['a'])
import 'package:test/test.dart';

void main() {
  test("foo", () {}, tags: "b");
}
""").create();

      testRun = runTest(["-x", "a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("No tests ran")));
      testRun.shouldExit(0);
    });

    test('parses a string into a tag', () {
      d.file("test.dart", """
@Tags('a')
import 'package:test/test.dart';

void main() {
  test("foo", () {}, tags: "b");
}
""").create();

      testRun = runTest(["-x", "a", "test.dart"]);
      testRun.stdout.expect(consumeThrough(contains("No tests ran")));
      testRun.shouldExit(0);
    });

    test('refuses bad arguments', () {
      d.file("test.dart", """
@Tags(1)
import 'package:test/test.dart';

void main() {}
""").create();

      testRun = runTest(["test.dart"]);
      testRun.stdout.expect(consumeThrough(
          contains("Only String or List literal allowed as @Tags argument")));
      testRun.shouldExit(1);
    });
  });
}
