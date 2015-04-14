// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../../io.dart';

String _sandbox;

final _success = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""";

final _failure = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("failure", () => throw new TestFailure("oh no"));
}
""";

void main() {
  setUp(() {
    _sandbox = createTempDir();
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  group("fails gracefully if", () {
    test("a test file fails to compile", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("invalid Dart file");
      var result = _runUnittest(["-p", "chrome", "test.dart"]);

      expect(result.stdout,
          contains("Expected a declaration, but got 'invalid'"));
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": dart2js '
                'failed.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file throws", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main() => throw 'oh no';");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": oh no')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file doesn't have a main defined", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void foo() {}");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": No '
                'top-level main() function defined.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file has a non-function main", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("int main;");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Top-level main getter is not a function.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file has a main with arguments", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Top-level main() function takes arguments.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    // TODO(nweiz): test what happens when a test file is unreadable once issue
    // 15078 is fixed.
  });

  group("runs successful tests", () {
    test("on Chrome", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("on PhantomJS", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "phantomjs", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("on Firefox", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "firefox", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("on Dartium", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, isNot(contains("Compiling")));
      expect(result.exitCode, equals(0));
    });

    test("on content shell", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "content-shell", "test.dart"]);
      expect(result.stdout, isNot(contains("Compiling")));
      expect(result.exitCode, equals(0));
    });

    test("on multiple browsers", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "firefox", "-p", "chrome", "test.dart"]);
      expect("Compiling".allMatches(result.stdout), hasLength(1));
      expect(result.exitCode, equals(0));
    });

    test("on a JS and non-JS browser", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(
          ["-p", "content-shell", "-p", "chrome", "test.dart"]);
      expect("Compiling".allMatches(result.stdout), hasLength(1));
      expect(result.exitCode, equals(0));
    });

    test("on the browser and the VM", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "chrome", "-p", "vm", "test.dart"]);
      expect(result.exitCode, equals(0));
    });
  });

  group("runs failing tests", () {
    test("on Chrome", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on PhantomJS", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "phantomjs", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on Firefox", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "firefox", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on Dartium", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on content-shell", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "content-shell", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("that fail only on the browser", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("test", () {
    if (p.style == p.Style.url) throw new TestFailure("oh no");
  });
}
""");
      var result = _runUnittest(["-p", "chrome", "-p", "vm", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("that fail only on the VM", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("test", () {
    if (p.style != p.Style.url) throw new TestFailure("oh no");
  });
}
""");
      var result = _runUnittest(["-p", "chrome", "-p", "vm", "test.dart"]);
      expect(result.exitCode, equals(1));
    });
  });

  test("forwards prints from the browser test", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test", () {
    print("Hello,");
    return new Future(() => print("world!"));
  });
}
""");

    var result = _runUnittest(["-p", "chrome", "test.dart"]);
    expect(result.stdout, contains("Hello,\nworld!\n"));
    expect(result.exitCode, equals(0));
  });
}

ProcessResult _runUnittest(List<String> args) =>
    runUnittest(args, workingDirectory: _sandbox);
