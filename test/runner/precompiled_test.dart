// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../io.dart';

void main() {
  group("browser tests", () {
    test("runs a precompiled version of a test rather than recompiling",
        () async {
      await d.file("to_precompile.dart", """
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

      await d.dir("precompiled", [
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

      var dart2js = await TestProcess.start(
          p.join(sdkDir, "bin", "dart2js"),
          [
            await PackageResolver.current.processArgument,
            "to_precompile.dart",
            "--out=precompiled/test.dart.browser_test.dart.js"
          ],
          workingDirectory: d.sandbox);
      await dart2js.shouldExit(0);

      await d.file("test.dart", "invalid dart}").create();

      var test = await runTest(
          ["-p", "chrome", "--precompiled=precompiled/", "test.dart"]);
      expect(test.stdout,
          containsInOrder(["+0: success", "+1: All tests passed!"]));
      await test.shouldExit(0);
    });
  }, tags: const ["chrome"]);

  group("vm tests", () {
    test("run in the precompiled directory", () async {
      await d.dir('test', [
        d.file("test.dart", """
          import "package:test/test.dart";
          void main() {
            test("true is true", () {
              expect(true, isTrue);
            });
          }
        """),
        d.file("test.dart.vm_test.dart", """
          import "dart:isolate";
          import "package:test/src/bootstrap/vm.dart";
          import "test.dart" as test;
          void main(_, SendPort message) {
            internalBootstrapVmTest(() => test.main, message);
          }
        """),
      ]).create();
      var currentPackages = await PackageResolver.current.packageConfigMap;
      var packagesFileContent = new StringBuffer();
      currentPackages.forEach((package, location) {
        packagesFileContent.writeln('$package:$location');
      });
      await d.file(".packages", packagesFileContent.toString()).create();

      var test = await runTest(
          ["-p", "vm", '--precompiled=${d.sandbox}', 'test/test.dart']);
      expect(test.stdout,
          containsInOrder(["+0: true is true", "+1: All tests passed!"]));
      await test.shouldExit(0);
    });
  });
}
