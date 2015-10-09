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

  test("an error causes the run to fail", () {
    d.file("test.dart", r"""
        import 'package:test/test.dart';

        void main() {
          tearDownAll(() => throw "oh no");

          test("test", () {});
        }
        """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("-1: (tearDownAll)")));
    test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
    test.shouldExit(1);
  });

  test("doesn't run if no tests in the group are selected", () {
    d.file("test.dart", r"""
        import 'package:test/test.dart';

        void main() {
          group("with tearDownAll", () {
            tearDownAll(() => throw "oh no");

            test("test", () {});
          });

          group("without tearDownAll", () {
            test("test", () {});
          });
        }
        """).create();

    var test = runTest(["test.dart", "--name", "without"]);
    test.stdout.expect(never(contains("(tearDownAll)")));
    test.shouldExit(0);
  });

  test("doesn't run if no tests in the group are selected", () {
    d.file("test.dart", r"""
        import 'package:test/test.dart';

        void main() {
          group("group", () {
            tearDownAll(() => throw "oh no");

            test("with", () {});
          });

          group("group", () {
            test("without", () {});
          });
        }
        """).create();

    var test = runTest(["test.dart", "--name", "without"]);
    test.stdout.expect(never(contains("(tearDownAll)")));
    test.shouldExit(0);
  });

  test("doesn't run if no tests in the group match the platform", () {
    d.file("test.dart", r"""
        import 'package:test/test.dart';

        void main() {
          group("group", () {
            tearDownAll(() => throw "oh no");

            test("with", () {}, testOn: "browser");
          });

          group("group", () {
            test("without", () {});
          });
        }
        """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(never(contains("(tearDownAll)")));
    test.shouldExit(0);
  });

  test("doesn't run if the group doesn't match the platform", () {
    d.file("test.dart", r"""
        import 'package:test/test.dart';

        void main() {
          group("group", () {
            tearDownAll(() => throw "oh no");

            test("with", () {});
          }, testOn: "browser");

          group("group", () {
            test("without", () {});
          });
        }
        """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(never(contains("(tearDownAll)")));
    test.shouldExit(0);
  });
}
