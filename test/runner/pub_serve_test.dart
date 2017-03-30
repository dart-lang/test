// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
@Tags(const ["pub"])
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/util/exit_codes.dart' as exit_codes;

import '../io.dart';

/// The `--pub-serve` argument for the test process, based on [pubServePort].
Future<String> get _pubServeArg =>
    pubServePort.then((port) => '--pub-serve=$port');

void main() {
  useSandbox(() {
    d
        .file(
            "pubspec.yaml",
            """
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
transformers:
- myapp:
    \$include: test/**_test.dart
- test/pub_serve:
    \$include: test/**_test.dart
""")
        .create();

    d.dir("test", [
      d.file(
          "my_test.dart",
          """
import 'package:test/test.dart';

void main() {
  test("test", () => expect(true, isTrue));
}
""")
    ]).create();

    d.dir("lib", [
      d.file(
          "myapp.dart",
          """
import 'package:barback/barback.dart';

class MyTransformer extends Transformer {
  final allowedExtensions = '.dart';

  MyTransformer.asPlugin();

  Future apply(Transform transform) async {
    var contents = await transform.primaryInput.readAsString();
    transform.addOutput(new Asset.fromString(
        transform.primaryInput.id,
        contents.replaceAll("isFalse", "isTrue")));
  }
}
""")
    ]).create();

    runPub(['get']).shouldExit(0);
  });

  group("with transformed tests", () {
    setUp(() {
      // Give the test a failing assertion that the transformer will convert to
      // a passing assertion.
      d
          .file(
              "test/my_test.dart",
              """
import 'package:test/test.dart';

void main() {
  test("test", () => expect(true, isFalse));
}
""")
          .create();
    });

    test("runs those tests in the VM", () {
      var pub = runPubServe();
      var test = runTest([_pubServeArg]);
      test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
      test.shouldExit(0);
      pub.kill();
    });

    test("runs those tests on Chrome", () {
      var pub = runPubServe();
      var test = runTest([_pubServeArg, '-p', 'chrome']);
      test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
      test.shouldExit(0);
      pub.kill();
    }, tags: 'chrome');

    test("runs those tests on content shell", () {
      var pub = runPubServe();
      var test = runTest([_pubServeArg, '-p', 'content-shell']);
      test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
      test.shouldExit(0);
      pub.kill();
    }, tags: 'content-shell');

    test(
        "gracefully handles pub serve running on the wrong directory for "
        "VM tests", () {
      d.dir("web").create();

      var pub = runPubServe(args: ['web']);
      var test = runTest([_pubServeArg]);
      test.stdout.expect(containsInOrder([
        '-1: loading ${p.join("test", "my_test.dart")} [E]',
        'Failed to load "${p.join("test", "my_test.dart")}":',
        '404 Not Found',
        'Make sure "pub serve" is serving the test/ directory.'
      ]));
      test.shouldExit(1);

      pub.kill();
    });

    group(
        "gracefully handles pub serve running on the wrong directory for "
        "browser tests", () {
      test("when run on Chrome", () {
        d.dir("web").create();

        var pub = runPubServe(args: ['web']);
        var test = runTest([_pubServeArg, '-p', 'chrome']);
        test.stdout.expect(containsInOrder([
          '-1: compiling ${p.join("test", "my_test.dart")} [E]',
          'Failed to load "${p.join("test", "my_test.dart")}":',
          '404 Not Found',
          'Make sure "pub serve" is serving the test/ directory.'
        ]));
        test.shouldExit(1);

        pub.kill();
      }, tags: 'chrome');

      test("when run on content shell", () {
        d.dir("web").create();

        var pub = runPubServe(args: ['web']);
        var test = runTest([_pubServeArg, '-p', 'content-shell']);
        test.stdout.expect(containsInOrder([
          '-1: loading ${p.join("test", "my_test.dart")} [E]',
          'Failed to load "${p.join("test", "my_test.dart")}":',
          '404 Not Found',
          'Make sure "pub serve" is serving the test/ directory.'
        ]));
        test.shouldExit(1);

        pub.kill();
      }, tags: 'content-shell');
    });

    test("gracefully handles unconfigured transformers", () {
      d
          .file(
              "pubspec.yaml",
              """
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
""")
          .create();

      var pub = runPubServe();
      var test = runTest([_pubServeArg]);
      expectStderrEquals(
          test,
          '''
When using --pub-serve, you must include the "test/pub_serve" transformer in
your pubspec:

transformers:
- test/pub_serve:
    \$include: test/**_test.dart
''');
      test.shouldExit(exit_codes.data);

      pub.kill();
    });
  });

  group("uses a custom HTML file", () {
    setUp(() {
      d.dir("test", [
        d.file(
            "test.dart",
            """
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("failure", () {
    expect(document.query('#foo'), isNull);
  });
}
"""),
        d.file(
            "test.html",
            """
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
""")
      ]).create();
    });

    test("on Chrome", () {
      var pub = runPubServe();
      var test = runTest([_pubServeArg, '-p', 'chrome']);
      test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
      test.shouldExit(0);
      pub.kill();
    }, tags: 'chrome');

    test("on content shell", () {
      var pub = runPubServe();
      var test = runTest([_pubServeArg, '-p', 'content-shell']);
      test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
      test.shouldExit(0);
      pub.kill();
    }, tags: 'content-shell');
  });

  group("with a failing test", () {
    setUp(() {
      d
          .file(
              "test/my_test.dart",
              """
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("failure", () => throw 'oh no');
}
""")
          .create();
    });

    test("dartifies stack traces for JS-compiled tests by default", () {
      var pub = runPubServe();
      var test = runTest([_pubServeArg, '-p', 'chrome', '--verbose-trace']);
      test.stdout.expect(containsInOrder(
          [" main.<fn>", "package:test", "dart:async/zone.dart"]));
      test.shouldExit(1);
      pub.kill();
    }, tags: 'chrome');

    test("doesn't dartify stack traces for JS-compiled tests with --js-trace",
        () {
      var pub = runPubServe();
      var test = runTest(
          [_pubServeArg, '-p', 'chrome', '--js-trace', '--verbose-trace']);

      test.stdout.fork().expect(never(endsWith(" main.<fn>")));
      test.stdout.fork().expect(never(contains("package:test")));
      test.stdout.fork().expect(never(contains("dart:async/zone.dart")));
      test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
      test.shouldExit(1);

      pub.kill();
    }, tags: 'chrome');
  });

  test("gracefully handles pub serve not running for VM tests", () {
    var test = runTest(['--pub-serve=54321']);
    test.stdout.expect(containsInOrder([
      '-1: loading ${p.join("test", "my_test.dart")} [E]',
      'Failed to load "${p.join("test", "my_test.dart")}":',
      'Error getting http://localhost:54321/my_test.dart.vm_test.dart: '
          'Connection refused',
      'Make sure "pub serve" is running.'
    ]));
    test.shouldExit(1);
  });

  test("gracefully handles pub serve not running for browser tests", () {
    var test = runTest(['--pub-serve=54321', '-p', 'chrome']);
    var message = Platform.isWindows
        ? 'The remote computer refused the network connection.'
        : 'Connection refused (errno ';

    test.stdout.expect(containsInOrder([
      '-1: compiling ${p.join("test", "my_test.dart")} [E]',
      'Failed to load "${p.join("test", "my_test.dart")}":',
      'Error getting http://localhost:54321/my_test.dart.browser_test.dart.js'
          '.map: $message',
      'Make sure "pub serve" is running.'
    ]));
    test.shouldExit(1);
  }, tags: 'chrome');

  test("gracefully handles a test file not being in test/", () {
    schedule(() {
      new File(p.join(sandbox, 'test/my_test.dart'))
          .copySync(p.join(sandbox, 'my_test.dart'));
    });

    var test = runTest(['--pub-serve=54321', 'my_test.dart']);
    test.stdout.expect(containsInOrder([
      '-1: loading my_test.dart [E]',
      'Failed to load "my_test.dart": When using "pub serve", all test files '
          'must be in test/.'
    ]));
    test.shouldExit(1);
  });
}
