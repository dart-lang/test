// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/exit_codes.dart' as exit_codes;

import '../../io.dart';

void main() {
  useSandbox();

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

  group("errors", () {
    test("rejects an invalid tag type", () {
      d.file("dart_test.yaml", '{"tags": {12: null}}').create();

      var test = runTest([]);
      test.stderr.expect(containsInOrder([
        "tags key must be a string",
        "^^"
      ]));
      test.shouldExit(exit_codes.data);
    });

    test("rejects an invalid tag name", () {
      d.file("dart_test.yaml", JSON.encode({
        "tags": {"foo bar": null}
      })).create();

      var test = runTest([]);
      test.stderr.expect(containsInOrder([
        "Invalid tag. Tags must be (optionally hyphenated) Dart identifiers.",
        "^^^^^^^^^"
      ]));
      test.shouldExit(exit_codes.data);
    });

    test("rejects an inavlid tag map", () {
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

    test("rejects an inavlid tag configuration", () {
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
}
