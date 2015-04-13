// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/exit_codes.dart' as exit_codes;
import 'package:test/test.dart';

import '../io.dart';

final _lines = UTF8.decoder.fuse(const LineSplitter());

final _servingRegExp =
    new RegExp(r'^Serving myapp [a-z]+ on http://localhost:(\d+)$');

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
""");

    new Directory(p.join(_sandbox, "test")).createSync();

    new File(p.join(_sandbox, "test", "my_test.dart")).writeAsStringSync("""
import 'package:test/test.dart';

void main() {
  test("test", () => expect(true, isTrue));
}
""");
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  group("with transformed tests", () {
    setUp(() {
      new Directory(p.join(_sandbox, "lib")).createSync();

      new File(p.join(_sandbox, "lib", "myapp.dart")).writeAsStringSync("""
import 'package:barback/barback.dart';

class MyTransformer extends Transformer {
  final allowedExtensions = '.dart';

  MyTransformer.asPlugin();

  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((contents) {
      print("contents: \$contents");
      print("new contents: \${contents.replaceAll("isFalse", "isTrue")}");
      transform.addOutput(new Asset.fromString(
          transform.primaryInput.id,
          contents.replaceAll("isFalse", "isTrue")));
    });
  }
}
""");

      var pubGetResult = runPub(['get'], workingDirectory: _sandbox);
      expect(pubGetResult.exitCode, equals(0));
    });

    test("runs those tests in the VM", () {
      return startPub(['serve', '--port', '0'], workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runUnittest(['--pub-serve=${match[1]}'],
                workingDirectory: _sandbox);
            expect(result.exitCode, equals(0));
            expect(result.stdout, contains('+1: All tests passed!'));
          } finally {
            process.kill();
          }
        });
      });
    });

    test("runs those tests in the browser", () {
      return startPub(['serve', '--port', '0'],
              workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runUnittest(
                ['--pub-serve=${match[1]}', '-p', 'chrome'],
                workingDirectory: _sandbox);
            expect(result.exitCode, equals(0));
            expect(result.stdout, contains('+1: All tests passed!'));
          } finally {
            process.kill();
          }
        });
      });
    });

    test("gracefully handles pub serve running on the wrong directory for "
        "VM tests", () {
      new Directory(p.join(_sandbox, "web")).createSync();

      return startPub(['serve', '--port', '0', 'web'],
              workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runUnittest(['--pub-serve=${match[1]}'],
                workingDirectory: _sandbox);
            expect(result.stdout, allOf([
              contains('-1: load error'),
              contains('Failed to load "test/my_test.dart":'),
              contains('404 Not Found'),
              contains('Make sure "pub serve" is serving the test/ directory.')
            ]));
            expect(result.exitCode, equals(1));
          } finally {
            process.kill();
          }
        });
      });
    });

    test("gracefully handles pub serve running on the wrong directory for "
        "browser tests", () {
      new Directory(p.join(_sandbox, "web")).createSync();

      return startPub(['serve', '--port', '0', 'web'],
              workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runUnittest(
                ['--pub-serve=${match[1]}', '-p', 'chrome'],
                workingDirectory: _sandbox);
            expect(result.stdout, allOf([
              contains('-1: load error'),
              contains('Failed to load "test/my_test.dart":'),
              contains('404 Not Found'),
              contains('Make sure "pub serve" is serving the test/ directory.')
            ]));
            expect(result.exitCode, equals(1));
          } finally {
            process.kill();
          }
        });
      });
    });

    test("gracefully handles unconfigured transformers", () {
      new File(p.join(_sandbox, "pubspec.yaml")).writeAsStringSync("""
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
""");

      return startPub(['serve', '--port', '0'],
              workingDirectory: _sandbox)
          .then((process) {
        return _lines.bind(process.stdout)
            .firstWhere(_servingRegExp.hasMatch)
            .then((line) {
          var match = _servingRegExp.firstMatch(line);

          try {
            var result = runUnittest(['--pub-serve=${match[1]}'],
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
            process.kill();
          }
        });
      });
    });
  });

  test("gracefully handles pub serve not running for VM tests", () {
    var result = runUnittest(['--pub-serve=54321'],
        workingDirectory: _sandbox);
    expect(result.stdout, allOf([
      contains('-1: load error'),
      contains('''
  Failed to load "test/my_test.dart":
  Error getting http://localhost:54321/my_test.dart.vm_test.dart: Connection refused
  Make sure "pub serve" is running.''')
    ]));
    expect(result.exitCode, equals(1));
  });

  test("gracefully handles pub serve not running for browser tests", () {
    var result = runUnittest(['--pub-serve=54321', '-p', 'chrome'],
        workingDirectory: _sandbox);
    expect(result.stdout, allOf([
      contains('-1: load error'),
      contains('Failed to load "test/my_test.dart":'),
      contains('Error getting http://localhost:54321/my_test.dart.browser_test'
          '.dart.js: Connection refused (errno '),
      contains('Make sure "pub serve" is running.')
    ]));
    expect(result.exitCode, equals(1));
  });

  test("gracefully handles a test file not being in test/", () {
    new File(p.join(_sandbox, 'test/my_test.dart'))
        .copySync(p.join(_sandbox, 'my_test.dart'));

    var result = runUnittest(['--pub-serve=54321', 'my_test.dart'],
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
