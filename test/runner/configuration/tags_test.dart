// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:convert';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/exit_codes.dart' as exit_codes;

import '../../io.dart';

void main() {
  useSandbox();

  test("adds the specified tags", () {
    d.file("dart_test.yaml", JSON.encode({
      "add_tags": ["foo", "bar"]
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("test", () {});
      }
    """).create();

    var test = runTest(["--exclude-tag", "foo", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("No tests ran.")));
    test.shouldExit(0);

    test = runTest(["--exclude-tag", "bar", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("No tests ran.")));
    test.shouldExit(0);

    test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  group("tags", () {
    test("doesn't warn for tags that exist in the configuration", () {
      d.file("dart_test.yaml", JSON.encode({
        "tags": {"foo": null}
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(never(contains("Warning: Tags were used")));
      test.shouldExit(0);
    });

    test("applies tag-specific configuration only to matching tests", () {
      d.file("dart_test.yaml", JSON.encode({
        "tags": {"foo": {"timeout": "0s"}}
      })).create();

      d.file("test.dart", """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test 1", () => new Future.delayed(Duration.ZERO), tags: ['foo']);
          test("test 2", () => new Future.delayed(Duration.ZERO));
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "-1: test 1",
        "+1 -1: Some tests failed."
      ]));
      test.shouldExit(1);
    });

    test("supports tag selectors", () {
      d.file("dart_test.yaml", JSON.encode({
        "tags": {"foo && bar": {"timeout": "0s"}}
      })).create();

      d.file("test.dart", """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test 1", () => new Future.delayed(Duration.ZERO), tags: ['foo']);
          test("test 2", () => new Future.delayed(Duration.ZERO), tags: ['bar']);
          test("test 3", () => new Future.delayed(Duration.ZERO),
              tags: ['foo', 'bar']);
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+2 -1: test 3",
        "+2 -1: Some tests failed."
      ]));
      test.shouldExit(1);
    });

    test("allows tag inheritance via add_tags", () {
      d.file("dart_test.yaml", JSON.encode({
        "tags": {
          "foo": null,
          "bar": {"add_tags": ["foo"]}
        }
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test 1", () {}, tags: ['bar']);
          test("test 2", () {});
        }
      """).create();

      var test = runTest(["test.dart", "--tags", "foo"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    // Regression test for #503.
    test("skips tests whose tags are marked as skip", () {
      d.file("dart_test.yaml", JSON.encode({
        "tags": {"foo": {"skip": "some reason"}}
      })).create();

      d.file("test.dart", """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test 1", () => throw 'bad', tags: ['foo']);
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "some reason",
        "All tests skipped."
      ]));
      test.shouldExit(0);
    });
  });

  group("include_tags and exclude_tags", () {
    test("only runs tests with the included tags", () {
      d.file("dart_test.yaml", JSON.encode({
        "include_tags": "foo && bar"
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("zip", () {}, tags: "foo");
          test("zap", () {}, tags: "bar");
          test("zop", () {}, tags: ["foo", "bar"]);
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: zop",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("doesn't run tests with the excluded tags", () {
      d.file("dart_test.yaml", JSON.encode({
        "exclude_tags": "foo && bar"
      })).create();

      d.file("test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("zip", () {}, tags: "foo");
          test("zap", () {}, tags: "bar");
          test("zop", () {}, tags: ["foo", "bar"]);
        }
      """).create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(containsInOrder([
        "+0: zip",
        "+1: zap",
        "+2: All tests passed!"
      ]));
      test.shouldExit(0);
    });
  });

  group("errors", () {
    group("tags", () {
      test("rejects an invalid tag type", () {
        d.file("dart_test.yaml", '{"tags": {12: null}}').create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "tags key must be a string",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid tag selector", () {
        d.file("dart_test.yaml", JSON.encode({
          "tags": {"foo bar": null}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid tags key: Expected end of input.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid tag map", () {
        d.file("dart_test.yaml", JSON.encode({
          "tags": 12
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "tags must be a map",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid tag configuration", () {
        d.file("dart_test.yaml", JSON.encode({
          "tags": {"foo": {"timeout": "12p"}}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid timeout: expected unit",
          "^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects runner configuration", () {
        d.file("dart_test.yaml", JSON.encode({
          "tags": {"foo": {"filename": "*_blorp.dart"}}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "filename isn't supported here.",
          "^^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });

    group("add_tags", () {
      test("rejects an invalid list type", () {
        d.file("dart_test.yaml", JSON.encode({
          "add_tags": "foo"
        })).create();

        var test = runTest(["test.dart"]);
        test.stderr.expect(containsInOrder([
          "add_tags must be a list",
          "^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid tag type", () {
        d.file("dart_test.yaml", JSON.encode({
          "add_tags": [12]
        })).create();

        var test = runTest(["test.dart"]);
        test.stderr.expect(containsInOrder([
          "Tag name must be a string",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid tag name", () {
        d.file("dart_test.yaml", JSON.encode({
          "add_tags": ["foo bar"]
        })).create();

        var test = runTest(["test.dart"]);
        test.stderr.expect(containsInOrder([
          "Tag name must be an (optionally hyphenated) Dart identifier.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });

    group("include_tags", () {
      test("rejects an invalid type", () {
        d.file("dart_test.yaml", JSON.encode({
          "include_tags": 12
        })).create();

        var test = runTest(["test.dart"]);
        test.stderr.expect(containsInOrder([
          "include_tags must be a string",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid selector", () {
        d.file("dart_test.yaml", JSON.encode({
          "include_tags": "foo bar"
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid include_tags: Expected end of input.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });

    group("exclude_tags", () {
      test("rejects an invalid type", () {
        d.file("dart_test.yaml", JSON.encode({
          "exclude_tags": 12
        })).create();

        var test = runTest(["test.dart"]);
        test.stderr.expect(containsInOrder([
          "exclude_tags must be a string",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid selector", () {
        d.file("dart_test.yaml", JSON.encode({
          "exclude_tags": "foo bar"
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid exclude_tags: Expected end of input.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });
  });
}
