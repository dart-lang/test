// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/test.dart';

import '../io.dart';

String _sandbox;

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('test_').path;

    new File(p.join(_sandbox, "pubspec.yaml")).writeAsStringSync("""
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
transformers:
- myapp:
    \$include: test/**_test.dart
- test/pub_serve:
    \$include: test/**_test.dart
dependency_overrides:
  matcher: '0.12.0-alpha.0'
""");

    new Directory(p.join(_sandbox, "test")).createSync();

    new File(p.join(_sandbox, "test", "my_test.dart")).writeAsStringSync("""
import 'package:test/test.dart';

void main() {
  test("test", () => expect(true, isTrue));
}
""");

    new Directory(p.join(_sandbox, "lib")).createSync();

    new File(p.join(_sandbox, "lib", "myapp.dart")).writeAsStringSync("""
import 'package:barback/barback.dart';

class MyTransformer extends Transformer {
  final allowedExtensions = '.dart';

  MyTransformer.asPlugin();

  Future apply(Transform transform) async {
    var contents = await transform.primaryInput.readAsString();
    print("contents: \$contents");
    print("new contents: \${contents.replaceAll("isFalse", "isTrue")}");
    transform.addOutput(new Asset.fromString(
        transform.primaryInput.id,
        contents.replaceAll("isFalse", "isTrue")));
  }
}
""");

    var pubGetResult = runPub(['get'], workingDirectory: _sandbox);
    expect(pubGetResult.exitCode, equals(0));
  });

  tearDown(() {
    // On Windows, there's no way to shut down the actual "pub serve" process.
    // Killing the process we start will just kill the batch file wrapper (issue
    // 23304), not the underlying "pub serve" process. Since that process has
    // locks on files in the sandbox, we can't delete the sandbox on Windows
    // without errors.
    if (Platform.isWindows) return;

    new Directory(_sandbox).deleteSync(recursive: true);
  });

  group("with transformed tests", () {
    test("runs those tests in the VM", () async {
      var pair = await startPubServe(workingDirectory: _sandbox);
      try {
        var result = runTest(['--pub-serve=${pair.last}'],
            workingDirectory: _sandbox);
        expect(result.exitCode, equals(0));
        expect(result.stdout, contains('+1: All tests passed!'));
      } finally {
        pair.first.kill();
      }
    });

    test("runs those tests on Chrome", () async {
      var pair = await startPubServe(workingDirectory: _sandbox);
      try {
        var result = runTest(['--pub-serve=${pair.last}', '-p', 'chrome'],
            workingDirectory: _sandbox);
        expect(result.exitCode, equals(0));
        expect(result.stdout, contains('+1: All tests passed!'));
      } finally {
        pair.first.kill();
      }
    });

    test("runs those tests on content shell", () async {
      var pair = await startPubServe(workingDirectory: _sandbox);
      try {
        var result = runTest(
            ['--pub-serve=${pair.last}', '-p', 'content-shell'],
            workingDirectory: _sandbox);
        expect(result.exitCode, equals(0));
        expect(result.stdout, contains('+1: All tests passed!'));
      } finally {
        pair.first.kill();
      }
    });

    test("gracefully handles pub serve running on the wrong directory for "
        "VM tests", () async {
      new Directory(p.join(_sandbox, "web")).createSync();

      var pair = await startPubServe(args: ['web'], workingDirectory: _sandbox);
      try {
        var result = runTest(['--pub-serve=${pair.last}'],
            workingDirectory: _sandbox);
        expect(result.stdout, allOf([
          contains('-1: load error'),
          contains('Failed to load "${p.join("test", "my_test.dart")}":'),
          contains('404 Not Found'),
          contains('Make sure "pub serve" is serving the test/ directory.')
        ]));
        expect(result.exitCode, equals(1));
      } finally {
        pair.first.kill();
      }
    });

    test("gracefully handles pub serve running on the wrong directory for "
        "browser tests", () async {
      new Directory(p.join(_sandbox, "web")).createSync();

      var pair = await startPubServe(args: ['web'], workingDirectory: _sandbox);
      try {
        var result = runTest(['--pub-serve=${pair.last}', '-p', 'chrome'],
            workingDirectory: _sandbox);
        expect(result.stdout, allOf([
          contains('-1: load error'),
          contains('Failed to load "${p.join("test", "my_test.dart")}":'),
          contains('404 Not Found'),
          contains('Make sure "pub serve" is serving the test/ directory.')
        ]));
        expect(result.exitCode, equals(1));
      } finally {
        pair.first.kill();
      }
    });

    test("gracefully handles unconfigured transformers", () async {
      new File(p.join(_sandbox, "pubspec.yaml")).writeAsStringSync("""
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
""");

      var pair = await startPubServe(workingDirectory: _sandbox);
      try {
        var result = runTest(['--pub-serve=${pair.last}'],
            workingDirectory: _sandbox);
        expect(result.exitCode, equals(exit_codes.data));
        expect(result.stderr, equals('''
When using --pub-serve, you must include the "test/pub_serve" transformer in
your pubspec:

transformers:
- test/pub_serve:
    \$include: test/**_test.dart
'''));
      } finally {
        pair.first.kill();
      }
    });
  });

  group("uses a custom HTML file", () {
    setUp(() {
      new File(p.join(_sandbox, "test", "test.dart")).writeAsStringSync("""
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("failure", () {
    expect(document.query('#foo'), isNull);
  });
}
""");

      new File(p.join(_sandbox, "test", "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
""");
    });

    test("on Chrome", () async {
      var pair = await startPubServe(workingDirectory: _sandbox);
      try {
        var result = runTest(['--pub-serve=${pair.last}', '-p', 'chrome'],
            workingDirectory: _sandbox);
        expect(result.exitCode, equals(0));
        expect(result.stdout, contains('+1: All tests passed!'));
      } finally {
        pair.first.kill();
      }
    });

    test("on content shell", () async {
      var pair = await startPubServe(workingDirectory: _sandbox);
      try {
        var result = runTest(
            ['--pub-serve=${pair.last}', '-p', 'content-shell'],
            workingDirectory: _sandbox);
        expect(result.exitCode, equals(0));
        expect(result.stdout, contains('+1: All tests passed!'));
      } finally {
        pair.first.kill();
      }
    });
  });


  group("with a failing test", () {
    setUp(() {
      new File(p.join(_sandbox, "test", "my_test.dart")).writeAsStringSync("""
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("failure", () => throw 'oh no');
}
""");
    });

    test("dartifies stack traces for JS-compiled tests by default", () {
      return startPub(['serve', '--port', '0'], workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runTest([
              '--pub-serve=${match[1]}',
              '-p', 'chrome',
              '--verbose-trace'
            ], workingDirectory: _sandbox);
            expect(result.stdout, contains(" main.<fn>\n"));
            expect(result.stdout, contains("package:test"));
            expect(result.stdout, contains("dart:async/zone.dart"));
            expect(result.exitCode, equals(1));
          } finally {
            process.kill();
          }
        });
      });
    });

    test("doesn't dartify stack traces for JS-compiled tests with --js-trace",
        () {
      return startPub(['serve', '--port', '0'], workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runTest([
              '--pub-serve=${match[1]}',
              '-p', 'chrome',
              '--js-trace',
              '--verbose-trace'
            ], workingDirectory: _sandbox);
            expect(result.stdout, isNot(contains(" main.<fn>\n")));
            expect(result.stdout, isNot(contains("package:test")));
            expect(result.stdout, isNot(contains("dart:async/zone.dart")));
            expect(result.exitCode, equals(1));
          } finally {
            process.kill();
          }
        });
      });
    });
  });

  test("gracefully handles pub serve not running for VM tests", () {
    var result = runTest(['--pub-serve=54321'],
        workingDirectory: _sandbox);
    expect(result.stdout, allOf([
      contains('-1: load error'),
      contains('''
  Failed to load "${p.join("test", "my_test.dart")}":
  Error getting http://localhost:54321/my_test.dart.vm_test.dart: Connection refused
  Make sure "pub serve" is running.''')
    ]));
    expect(result.exitCode, equals(1));
  });

  test("gracefully handles pub serve not running for browser tests", () {
    var result = runTest(['--pub-serve=54321', '-p', 'chrome'],
        workingDirectory: _sandbox);
    var message = Platform.isWindows
        ? 'The remote computer refused the network connection.'
        : 'Connection refused (errno ';

    expect(result.stdout, allOf([
      contains('-1: load error'),
      contains('Failed to load "${p.join("test", "my_test.dart")}":'),
      contains('Error getting http://localhost:54321/my_test.dart.browser_test'
          '.dart.js: $message'),
      contains('Make sure "pub serve" is running.')
    ]));
    expect(result.exitCode, equals(1));
  });

  test("gracefully handles a test file not being in test/", () {
    new File(p.join(_sandbox, 'test/my_test.dart'))
        .copySync(p.join(_sandbox, 'my_test.dart'));

    var result = runTest(['--pub-serve=54321', 'my_test.dart'],
        workingDirectory: _sandbox);
    expect(result.stdout, allOf([
      contains('-1: load error'),
      contains(
          'Failed to load "my_test.dart": When using "pub serve", all test '
              'files must be in test/.\n')
    ]));
    expect(result.exitCode, equals(1));
  });
}
