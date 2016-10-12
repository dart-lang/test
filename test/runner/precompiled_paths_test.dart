// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
@Tags(const ["chrome"])

import 'dart:io';

import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'package:test/src/util/io.dart';

import '../io.dart';

void main() {
  useSandbox();

  test("runs a precompiled version of a test rather than recompiling", () {
    d.file("to_precompile.dart", """
      import "package:stream_channel/stream_channel.dart";

      import "package:test/src/runner/plugin/remote_platform_helpers.dart";
      import "package:test/src/runner/browser/post_message_channel.dart";
      import "package:test/test.dart";

      main(_) async {
        var channel = serializeSuite(() {
          return () => test("success", () {});
        }, hidePrints: false);
        postMessageChannel().pipe(channel);
      }
    """).create();

    d.dir("precompiled", [
      d.file("test.html", """
        <!DOCTYPE html>
        <html>
        <head>
          <title>test Test</title>
          <script src="test.dart.browser_test.dart.js"></script>
        </head>
        </html>
      """)
    ]).create();

    var dart2js = new ScheduledProcess.start(p.join(sdkDir, 'bin', 'dart2js'), [
      PackageResolver.current.processArgument,
      "to_precompile.dart",
      "--out=precompiled/test.dart.browser_test.dart.js"
    ], workingDirectory: sandbox);
    dart2js.shouldExit(0);

    d.file("test.dart", "invalid dart}").create();

    var test = runTest(
        ["-p", "chrome", "--precompiled=precompiled/", "test.dart"]);
    test.stdout.expect(containsInOrder([
      "+0: success",
      "+1: All tests passed!"
    ]));
    test.shouldExit(0);
  });
}
