// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'dart:convert';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/src/util/io.dart';

import '../../io.dart';

void main() {
  useSandbox();

  group("presets", () {
    test("don't do anything by default", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"}
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      runTest(["test.dart"]).shouldExit(0);
    });

    test("can be selected on the command line", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"}
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      var test = runTest(["-P", "foo", "test.dart"]);
      test.stdout
          .expect(containsInOrder(["-1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);
    });

    test("multiple presets can be selected", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"},
                  "bar": {
                    "paths": ["test.dart"]
                  }
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      var test = runTest(["-P", "foo,bar"]);
      test.stdout
          .expect(containsInOrder(["-1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);
    });

    test("the latter preset takes precedence", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"},
                  "bar": {"timeout": "30s"}
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      runTest(["-P", "foo,bar", "test.dart"]).shouldExit(0);

      var test = runTest(["-P", "bar,foo", "test.dart"]);
      test.stdout
          .expect(containsInOrder(["-1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);
    });

    test("a preset takes precedence over the base configuration", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"}
                },
                "timeout": "30s"
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      var test = runTest(["-P", "foo", "test.dart"]);
      test.stdout
          .expect(containsInOrder(["-1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);

      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "30s"}
                },
                "timeout": "00s"
              }))
          .create();

      runTest(["-P", "foo", "test.dart"]).shouldExit(0);
    });

    test("a nested preset is activated", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "tags": {
                  "foo": {
                    "presets": {
                      "bar": {"timeout": "0s"}
                    },
                  },
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test 1", () => new Future.delayed(Duration.ZERO), tags: "foo");
          test("test 2", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      var test = runTest(["-P", "bar", "test.dart"]);
      test.stdout.expect(
          containsInOrder(["+0 -1: test 1 [E]", "+1 -1: Some tests failed."]));
      test.shouldExit(1);

      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "30s"}
                },
                "timeout": "00s"
              }))
          .create();

      runTest(["-P", "foo", "test.dart"]).shouldExit(0);
    });
  });

  group("add_presets", () {
    test("selects a preset", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"}
                },
                "add_presets": ["foo"]
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout
          .expect(containsInOrder(["-1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);
    });

    test("applies presets in selection order", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"},
                  "bar": {"timeout": "30s"}
                },
                "add_presets": ["foo", "bar"]
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      runTest(["test.dart"]).shouldExit(0);

      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {"timeout": "0s"},
                  "bar": {"timeout": "30s"}
                },
                "add_presets": ["bar", "foo"]
              }))
          .create();

      var test = runTest(["test.dart"]);
      test.stdout
          .expect(containsInOrder(["-1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);
    });

    test("allows preset inheritance via add_presets", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {
                    "add_presets": ["bar"]
                  },
                  "bar": {"timeout": "0s"}
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () => new Future.delayed(Duration.ZERO));
        }
      """)
          .create();

      var test = runTest(["-P", "foo", "test.dart"]);
      test.stdout.expect(
          containsInOrder(["+0 -1: test [E]", "-1: Some tests failed."]));
      test.shouldExit(1);
    });

    test("allows circular preset inheritance via add_presets", () {
      d
          .file(
              "dart_test.yaml",
              JSON.encode({
                "presets": {
                  "foo": {
                    "add_presets": ["bar"]
                  },
                  "bar": {
                    "add_presets": ["foo"]
                  }
                }
              }))
          .create();

      d
          .file(
              "test.dart",
              """
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      """)
          .create();

      runTest(["-P", "foo", "test.dart"]).shouldExit(0);
    });
  });

  group("errors", () {
    group("presets", () {
      test("rejects an invalid preset type", () {
        d.file("dart_test.yaml", '{"presets": {12: null}}').create();

        var test = runTest([]);
        test.stderr
            .expect(containsInOrder(["presets key must be a string", "^^"]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid preset name", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "presets": {"foo bar": null}
                }))
            .create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder([
          "presets key must be an (optionally hyphenated) Dart identifier.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid preset map", () {
        d.file("dart_test.yaml", JSON.encode({"presets": 12})).create();

        var test = runTest([]);
        test.stderr.expect(containsInOrder(["presets must be a map", "^^"]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid preset configuration", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "presets": {
                    "foo": {"timeout": "12p"}
                  }
                }))
            .create();

        var test = runTest([]);
        test.stderr.expect(
            containsInOrder(["Invalid timeout: expected unit", "^^^^"]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects runner configuration in a non-runner context", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "tags": {
                    "foo": {
                      "presets": {
                        "bar": {"filename": "*_blorp.dart"}
                      }
                    }
                  }
                }))
            .create();

        var test = runTest([]);
        test.stderr.expect(
            containsInOrder(["filename isn't supported here.", "^^^^^^^^^^"]));
        test.shouldExit(exit_codes.data);
      });

      test("fails if an undefined preset is passed", () {
        var test = runTest(["-P", "foo"]);
        test.stderr.expect(consumeThrough(contains('Undefined preset "foo".')));
        test.shouldExit(exit_codes.usage);
      });

      test("fails if an undefined preset is added", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "add_presets": ["foo", "bar"]
                }))
            .create();

        var test = runTest([]);
        test.stderr.expect(
            consumeThrough(contains('Undefined presets "foo" and "bar".')));
        test.shouldExit(exit_codes.usage);
      });

      test("fails if an undefined preset is added in a nested context", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "on_os": {
                    currentOS.identifier: {
                      "add_presets": ["bar"]
                    }
                  }
                }))
            .create();

        var test = runTest([]);
        test.stderr.expect(consumeThrough(contains('Undefined preset "bar".')));
        test.shouldExit(exit_codes.usage);
      });
    });

    group("add_presets", () {
      test("rejects an invalid list type", () {
        d.file("dart_test.yaml", JSON.encode({"add_presets": "foo"})).create();

        var test = runTest(["test.dart"]);
        test.stderr
            .expect(containsInOrder(["add_presets must be a list", "^^^^"]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid preset type", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "add_presets": [12]
                }))
            .create();

        var test = runTest(["test.dart"]);
        test.stderr
            .expect(containsInOrder(["Preset name must be a string", "^^"]));
        test.shouldExit(exit_codes.data);
      });

      test("rejects an invalid preset name", () {
        d
            .file(
                "dart_test.yaml",
                JSON.encode({
                  "add_presets": ["foo bar"]
                }))
            .create();

        var test = runTest(["test.dart"]);
        test.stderr.expect(containsInOrder([
          "Preset name must be an (optionally hyphenated) Dart identifier.",
          "^^^^^^^^^"
        ]));
        test.shouldExit(exit_codes.data);
      });
    });
  });
}
