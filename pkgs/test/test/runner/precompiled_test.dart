// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
import 'dart:async';
import 'dart:io';

import 'package:node_preamble/preamble.dart' as preamble;
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'package:test_core/src/util/io.dart';
import 'package:test/test.dart';

import '../io.dart';

void main() {
  group("browser tests", () {
    setUp(() async {
      await d.file("to_precompile.dart", """
        import "package:stream_channel/stream_channel.dart";

        import "package:test_core/src/runner/plugin/remote_platform_helpers.dart";
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
    });

    test("run a precompiled version of a test rather than recompiling",
        () async {
      var test = await runTest(
          ["-p", "chrome", "--precompiled=precompiled/", "test.dart"]);
      expect(test.stdout,
          containsInOrder(["+0: success", "+1: All tests passed!"]));
      await test.shouldExit(0);
    });

    test("can use the json reporter", () async {
      var test = await runTest([
        "-p",
        "chrome",
        "--precompiled=precompiled/",
        "test.dart",
        "-r",
        "json"
      ]);
      expect(
          test.stdout,
          containsInOrder([
            '{"testID":3,"result":"success"',
            '{"success":true,"type":"done"'
          ]));
      await test.shouldExit(0);
    });
  }, tags: const ["chrome"]);

  group("node tests", () {
    setUp(() async {
      await d.dir("test", [
        d.file("test.dart", """
          import "package:test/src/bootstrap/node.dart";
          import "package:test/test.dart";

          void main() {
            internalBootstrapNodeTest(() => () => test("success", () {
              expect(true, isTrue);
            }));
          }""")
      ]).create();
      await _writePackagesFile();

      var jsPath = p.join(d.sandbox, "test", "test.dart.node_test.dart.js");
      var dart2js = await TestProcess.start(
          p.join(sdkDir, "bin", "dart2js"),
          [
            await PackageResolver.current.processArgument,
            p.join("test", "test.dart"),
            "--out=$jsPath",
          ],
          workingDirectory: d.sandbox);
      await dart2js.shouldExit(0);

      var jsFile = File(jsPath);
      await jsFile.writeAsString(
          preamble.getPreamble(minified: true) + await jsFile.readAsString());

      await d.dir("test", [d.file("test.dart", "invalid dart}")]).create();
    });

    test("run a precompiled version of a test rather than recompiling",
        () async {
      var test = await runTest([
        "-p",
        "node",
        "--precompiled",
        d.sandbox,
        p.join("test", "test.dart")
      ]);
      expect(test.stdout,
          containsInOrder(["+0: success", "+1: All tests passed!"]));
      await test.shouldExit(0);
    });

    test("can use the json reporter", () async {
      var test = await runTest([
        "-p",
        "node",
        "--precompiled",
        d.sandbox,
        p.join("test", "test.dart"),
        '-r',
        'json'
      ]);
      expect(
          test.stdout,
          containsInOrder([
            '{"testID":3,"result":"success"',
            '{"success":true,"type":"done"'
          ]));
      await test.shouldExit(0);
    });
  }, tags: const ["node"]);

  group("vm tests", () {
    setUp(() async {
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
          import "package:test_core/src/bootstrap/vm.dart";
          import "test.dart" as test;
          void main(_, SendPort message) {
            internalBootstrapVmTest(() => test.main, message);
          }
        """),
      ]).create();
      await _writePackagesFile();
    });

    test("run in the precompiled directory", () async {
      var test = await runTest(
          ["-p", "vm", '--precompiled=${d.sandbox}', 'test/test.dart']);
      expect(test.stdout,
          containsInOrder(["+0: true is true", "+1: All tests passed!"]));
      await test.shouldExit(0);
    });

    test("can load precompiled dill files if available", () async {
      // Create the snapshot in the sandbox directory.
      var snapshotProcess = await runDart([
        '--snapshot_kind=script',
        '--snapshot=test/test.dart.vm_test.vm.app.dill',
        'test/test.dart.vm_test.dart'
      ]);
      await snapshotProcess.shouldExit(0);

      // Modify the original test so it would fail if it actually got ran, this
      // makes sure the test fails if the dill file isn't loaded.
      var testFile = File(p.join(d.sandbox, 'test', 'test.dart'));
      expect(await testFile.exists(), isTrue);
      var originalContent = await testFile.readAsString();
      await testFile
          .writeAsString(originalContent.replaceAll('isTrue', 'isFalse'));

      // Actually invoke the test with the dill file.
      var testProcess = await runTest(
          ["-p", "vm", '--precompiled=${d.sandbox}', 'test/test.dart']);
      expect(testProcess.stdout,
          containsInOrder(["+0: true is true", "+1: All tests passed!"]));
      await testProcess.shouldExit(0);
    });

    test("can use the json reporter", () async {
      var test = await runTest([
        "-p",
        "vm",
        '--precompiled=${d.sandbox}',
        'test/test.dart',
        '-r',
        'json'
      ]);
      expect(
          test.stdout,
          containsInOrder([
            '{"testID":3,"result":"success"',
            '{"success":true,"type":"done"'
          ]));
      await test.shouldExit(0);
    });
  });
}

Future<Null> _writePackagesFile() async {
  var currentPackages = await PackageResolver.current.packageConfigMap;
  var packagesFileContent = StringBuffer();
  currentPackages.forEach((package, location) {
    packagesFileContent.writeln('$package:$location');
  });
  await d.file(".packages", packagesFileContent.toString()).create();
}
