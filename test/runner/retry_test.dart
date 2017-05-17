// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
}
