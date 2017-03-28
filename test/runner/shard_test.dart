// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'package:test/src/util/exit_codes.dart' as exit_codes;

import '../io.dart';

void main() {
  useSandbox();

  test("divides all the tests among the available shards", () {
    d
        .file(
            "test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("test 1", () {});
        test("test 2", () {});
        test("test 3", () {});
        test("test 4", () {});
        test("test 5", () {});
        test("test 6", () {});
        test("test 7", () {});
        test("test 8", () {});
        test("test 9", () {});
        test("test 10", () {});
      }
    """)
        .create();

    var test = runTest(["test.dart", "--shard-index=0", "--total-shards=3"]);
    test.stdout.expect(containsInOrder(
        ["+0: test 1", "+1: test 2", "+2: test 3", "+3: All tests passed!"]));
    test.shouldExit(0);

    test = runTest(["test.dart", "--shard-index=1", "--total-shards=3"]);
    test.stdout.expect(containsInOrder([
      "+0: test 4",
      "+1: test 5",
      "+2: test 6",
      "+3: test 7",
      "+4: All tests passed!"
    ]));
    test.shouldExit(0);

    test = runTest(["test.dart", "--shard-index=2", "--total-shards=3"]);
    test.stdout.expect(containsInOrder(
        ["+0: test 8", "+1: test 9", "+2: test 10", "+3: All tests passed!"]));
    test.shouldExit(0);
  });

  test("shards each suite", () {
    d
        .file(
            "1_test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("test 1.1", () {});
        test("test 1.2", () {});
        test("test 1.3", () {});
      }
    """)
        .create();

    d
        .file(
            "2_test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("test 2.1", () {});
        test("test 2.2", () {});
        test("test 2.3", () {});
      }
    """)
        .create();

    var test = runTest([".", "--shard-index=0", "--total-shards=3"]);
    test.stdout.expect(inOrder([
      either(
          containsInOrder(
              ["+0: ./1_test.dart: test 1.1", "+1: ./2_test.dart: test 2.1"]),
          containsInOrder(
              ["+0: ./2_test.dart: test 2.1", "+1: ./1_test.dart: test 1.1"])),
      contains("+2: All tests passed!")
    ]));
    test.shouldExit(0);

    test = runTest([".", "--shard-index=1", "--total-shards=3"]);
    test.stdout.expect(inOrder([
      either(
          containsInOrder(
              ["+0: ./1_test.dart: test 1.2", "+1: ./2_test.dart: test 2.2"]),
          containsInOrder(
              ["+0: ./2_test.dart: test 2.2", "+1: ./1_test.dart: test 1.2"])),
      contains("+2: All tests passed!")
    ]));
    test.shouldExit(0);

    test = runTest([".", "--shard-index=2", "--total-shards=3"]);
    test.stdout.expect(inOrder([
      either(
          containsInOrder(
              ["+0: ./1_test.dart: test 1.3", "+1: ./2_test.dart: test 2.3"]),
          containsInOrder(
              ["+0: ./2_test.dart: test 2.3", "+1: ./1_test.dart: test 1.3"])),
      contains("+2: All tests passed!")
    ]));
    test.shouldExit(0);
  });

  test("an empty shard reports success", () {
    d
        .file(
            "test.dart",
            """
      import 'package:test/test.dart';

      void main() {
        test("test 1", () {});
        test("test 2", () {});
      }
    """)
        .create();

    var test = runTest(["test.dart", "--shard-index=1", "--total-shards=3"]);
    test.stdout.expect(consumeThrough("No tests ran."));
    test.shouldExit(0);
  });

  group("reports an error if", () {
    test("--shard-index is provided alone", () {
      var test = runTest(["--shard-index=1"]);
      test.stderr.expect(
          "--shard-index and --total-shards may only be passed together.");
      test.shouldExit(exit_codes.usage);
    });

    test("--total-shards is provided alone", () {
      var test = runTest(["--total-shards=5"]);
      test.stderr.expect(
          "--shard-index and --total-shards may only be passed together.");
      test.shouldExit(exit_codes.usage);
    });

    test("--shard-index is negative", () {
      var test = runTest(["--shard-index=-1", "--total-shards=5"]);
      test.stderr.expect("--shard-index may not be negative.");
      test.shouldExit(exit_codes.usage);
    });

    test("--shard-index is equal to --total-shards", () {
      var test = runTest(["--shard-index=5", "--total-shards=5"]);
      test.stderr.expect("--shard-index must be less than --total-shards.");
      test.shouldExit(exit_codes.usage);
    });
  });
}
