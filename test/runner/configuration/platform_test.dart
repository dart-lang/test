// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:convert';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/src/util/io.dart';

import '../../io.dart';

void main() {
  useSandbox();

  group("on_platform", () {
    test("applies platform-specific configuration to matching tests", () {
      d.file("dart_test.yaml", JSON.encode({
        "on_platform": {
          "content-shell": {"timeout": "0s"}
        }
      })).create();

      d.file("test.dart", """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """).create();

      var test = runTest(["-p", "content-shell,vm", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "-1: [Dartium Content Shell] test",
        "+1 -1: Some tests failed."
      ]));
      test.shouldExit(1);
    }, tags: ['content-shell']);

    test("supports platform selectors", () {
      d.file("dart_test.yaml", JSON.encode({
        "on_platform": {
          "content-shell || vm": {"timeout": "0s"}
        }
      })).create();

      d.file("test.dart", """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """).create();

      var test = runTest(["-p", "content-shell,vm", "test.dart"]);
      test.stdout.expect(containsInOrder([
        "-1: [VM] test",
        "-2: [Dartium Content Shell] test",
        "-2: Some tests failed."
      ]));
      test.shouldExit(1);
    }, tags: ['content-shell']);

    group("errors", () {
      test("rejects an invalid selector type", () {
        d.file("dart_test.yaml", '{"on_platform": {12: null}}').create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "on_platform key must be a string",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid selector", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_platform": {"foo bar": null}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid on_platform key: Expected end of input.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects a selector with an undefined variable", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_platform": {"foo": null}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid on_platform key: Undefined variable.",
          "^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid map", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_platform": {"linux": 12}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "on_platform value must be a map.",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid configuration", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_platform": {"linux": {"timeout": "12p"}}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid timeout: expected unit.",
          "^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects runner configuration", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_platform": {"linux": {"filename": "*_blorp"}}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "filename isn't supported here.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });
  });

  group("on_os", () {
    test("applies OS-specific configuration on a matching OS", () {
      d.file("dart_test.yaml", JSON.encode({
        "on_os": {
          currentOS.identifier: {"filename": "test_*.dart"}
        }
      })).create();

      d.file("foo_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("foo_test", () {});
        }
      """).create();

      d.file("test_foo.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test_foo", () {});
        }
      """).create();

      var test = runTest(["."]);
      test.stdout.expect(containsInOrder([
        "+0: ./test_foo.dart: test_foo",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    test("doesn't OS-specific configuration on a non-matching OS", () {
      d.file("dart_test.yaml", JSON.encode({
        "on_os": {
          otherOS: {"filename": "test_*.dart"}
        }
      })).create();

      d.file("foo_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("foo_test", () {});
        }
      """).create();

      d.file("test_foo.dart", """
        import 'package:test/test.dart';

        void main() {
          test("test_foo", () {});
        }
      """).create();

      var test = runTest(["."]);
      test.stdout.expect(containsInOrder([
        "+0: ./foo_test.dart: foo_test",
        "+1: All tests passed!"
      ]));
      test.shouldExit(0);
    });

    group("errors", () {
      test("rejects an invalid OS type", () {
        d.file("dart_test.yaml", '{"on_os": {12: null}}').create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "on_os key must be a string",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an unknown OS name", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_os": {"foo": null}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid on_os key: No such operating system.",
          "^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid map", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_os": {"linux": 12}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "on_os value must be a map.",
          "^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid configuration", () {
        d.file("dart_test.yaml", JSON.encode({
          "on_os": {"linux": {"timeout": "12p"}}
        })).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "Invalid timeout: expected unit.",
          "^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });
  });
}
