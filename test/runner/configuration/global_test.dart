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

  test("ignores an empty file", () {
    d.file("global_test.yaml", "").create();

    d
        .file(
            "test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """)
        .create();

    var test = runTest(["test.dart"],
        environment: {"DART_TEST_CONFIG": "global_test.yaml"});
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  test("uses supported test configuration", () {
    d.file("global_test.yaml", JSON.encode({"verbose_trace": true})).create();

    d
        .file(
            "test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """)
        .create();

    var test = runTest(["test.dart"],
        environment: {"DART_TEST_CONFIG": "global_test.yaml"});
    test.stdout.expect(consumeThrough(contains("dart:isolate-patch")));
    test.shouldExit(1);
  });

  test("uses supported runner configuration", () {
    d.file("global_test.yaml", JSON.encode({"reporter": "json"})).create();

    d
        .file(
            "test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """)
        .create();

    var test = runTest(["test.dart"],
        environment: {"DART_TEST_CONFIG": "global_test.yaml"});
    test.stdout.expect(consumeThrough(contains('"testStart"')));
    test.shouldExit(0);
  });

  test("local configuration takes precedence", () {
    d.file("global_test.yaml", JSON.encode({"verbose_trace": true})).create();

    d.file("dart_test.yaml", JSON.encode({"verbose_trace": false})).create();

    d
        .file(
            "test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """)
        .create();

    var test = runTest(["test.dart"],
        environment: {"DART_TEST_CONFIG": "global_test.yaml"});
    test.stdout.expect(never(contains("dart:isolate-patch")));
    test.shouldExit(1);
  });

  group("disallows local-only configuration:", () {
    for (var field in [
      "skip",
      "retry",
      "test_on",
      "paths",
      "filename",
      "names",
      "plain_names",
      "include_tags",
      "exclude_tags",
      "pub_serve",
      "tags",
      "add_tags"
    ]) {
      test("rejects local-only configuration", () {
        d.file("global_test.yaml", JSON.encode({field: null})).create();

        d
            .file(
                "test.dart",
                """
          import 'package:test/test.dart';

          void main() {
            test("success", () {});
          }
        """)
            .create();

        var test = runTest(["test.dart"],
            environment: {"DART_TEST_CONFIG": "global_test.yaml"});
        test.stderr.expect(containsInOrder(
            ["of global_test.yaml: $field isn't supported here.", "^^"]));
        test.shouldExit(exit_codes.data);
      });
    }
  });
}
