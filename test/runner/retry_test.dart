// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
@TestOn("vm")
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

void main() {
  useSandbox();

  test("respects top-level @Retry declarations", () {
    d
        .file(
            "test.dart",
            """
          @Retry(3)

          import 'dart:async';

          import 'package:test/test.dart';


          int attempt = 0;
          void main() {
            test("failure", () {
             attempt++;
             if(attempt <= 3) {
               throw new TestFailure("oh no");
             }
            });
          }
          """)
        .create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  group("retries tests", () {
    test("and eventually passes for valid tests", () {
      d
          .file(
              "test.dart",
              """
              import 'dart:async';

              import 'package:test/test.dart';

              int attempt = 0;
              void main() {
                test("eventually passes", () {
                 attempt++;
                 if(attempt <= 2) {
                   throw new TestFailure("oh no");
                 }
                }, retry: 2);
              }
          """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });


    test("and ignores previous errors", () {
      d
          .file(
              "test.dart",
              """
              import 'dart:async';

              import 'package:test/test.dart';

              int attempt = 0;
              Completer completer = new Completer();
              void main() {
                test("failure", () {
                  attempt++;
                  if (attempt == 1) {
                    completer.future.then((_) => throw 'some error');
                    throw new TestFailure("oh no");
                  }
                  completer.complete(null);
                }, retry: 1);
              }
          """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });

    test("and eventually fails for invalid tests", () {
      d
          .file(
              "test.dart",
              """
              import 'dart:async';

              import 'package:test/test.dart';

              void main() {
                test("failure", () {
                 throw new TestFailure("oh no");
                }, retry: 2);
              }
          """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
      test.shouldExit(1);
    });

    test("only after a failure", () {
      d
          .file(
              "test.dart",
              """
              import 'dart:async';

              import 'package:test/test.dart';

              int attempt = 0;
              void main() {
                test("eventually passes", () {
                attempt++;
                if (attempt != 2){
                 throw new TestFailure("oh no");
                }
                }, retry: 5);
          }
          """)
          .create();

      var test = runTest(["test.dart"]);
      test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
      test.shouldExit(0);
    });
  });
}
