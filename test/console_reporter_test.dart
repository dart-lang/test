// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unittest/src/io.dart';
import 'package:unittest/unittest.dart';

import 'io.dart';

String _sandbox;

void main() {
  test("reports when no tests are run", () {
    return withTempDir((path) {
      new File(p.join(path, "test.dart")).writeAsStringSync("void main() {}");
      var result = runUnittest(["test.dart"], workingDirectory: path);
      expect(result.stdout, equals("No tests ran.\n"));
    });
  });

  test("runs several successful tests and reports when each completes", () {
    _expectReport("""
        declarer.test('success 1', () {});
        declarer.test('success 2', () {});
        declarer.test('success 3', () {});""",
        """
        +0: success 1
        +1: success 1
        +1: success 2
        +2: success 2
        +2: success 3
        +3: success 3
        +3: All tests passed!""");
  });

  test("runs several failing tests and reports when each fails", () {
    _expectReport("""
        declarer.test('failure 1', () => throw new TestFailure('oh no'));
        declarer.test('failure 2', () => throw new TestFailure('oh no'));
        declarer.test('failure 3', () => throw new TestFailure('oh no'));""",
        """
        +0: failure 1
        +0 -1: failure 1
          oh no
          test.dart 7:42  main.<fn>
          dart:isolate    _RawReceivePortImpl._handleMessage


        +0 -1: failure 2
        +0 -2: failure 2
          oh no
          test.dart 8:42  main.<fn>
          dart:isolate    _RawReceivePortImpl._handleMessage


        +0 -2: failure 3
        +0 -3: failure 3
          oh no
          test.dart 9:42  main.<fn>
          dart:isolate    _RawReceivePortImpl._handleMessage


        +0 -3: Some tests failed.""");
  });

  test("runs failing tests along with successful tests", () {
    _expectReport("""
        declarer.test('failure 1', () => throw new TestFailure('oh no'));
        declarer.test('success 1', () {});
        declarer.test('failure 2', () => throw new TestFailure('oh no'));
        declarer.test('success 2', () {});""",
        """
        +0: failure 1
        +0 -1: failure 1
          oh no
          test.dart 7:42  main.<fn>
          dart:isolate    _RawReceivePortImpl._handleMessage


        +0 -1: success 1
        +1 -1: success 1
        +1 -1: failure 2
        +1 -2: failure 2
          oh no
          test.dart 9:42  main.<fn>
          dart:isolate    _RawReceivePortImpl._handleMessage


        +1 -2: success 2
        +2 -2: success 2
        +2 -2: Some tests failed.""");
  });

  test("gracefully handles multiple test failures in a row", () {
    _expectReport("""
        // This completer ensures that the test isolate isn't killed until all
        // errors have been thrown.
        var completer = new Completer();
        declarer.test('failures', () {
          new Future.microtask(() => throw 'first error');
          new Future.microtask(() => throw 'second error');
          new Future.microtask(() => throw 'third error');
          new Future.microtask(completer.complete);
        });
        declarer.test('wait', () => completer.future);""",
        """
        +0: failures
        +0 -1: failures
          first error
          test.dart 11:38  main.<fn>.<fn>
          dart:isolate     _RawReceivePortImpl._handleMessage
          ===== asynchronous gap ===========================
          dart:async       Future.Future.microtask
          test.dart 11:15  main.<fn>
          dart:isolate     _RawReceivePortImpl._handleMessage


          second error
          test.dart 12:38  main.<fn>.<fn>
          dart:isolate     _RawReceivePortImpl._handleMessage
          ===== asynchronous gap ===========================
          dart:async       Future.Future.microtask
          test.dart 12:15  main.<fn>
          dart:isolate     _RawReceivePortImpl._handleMessage


          third error
          test.dart 13:38  main.<fn>.<fn>
          dart:isolate     _RawReceivePortImpl._handleMessage
          ===== asynchronous gap ===========================
          dart:async       Future.Future.microtask
          test.dart 13:15  main.<fn>
          dart:isolate     _RawReceivePortImpl._handleMessage


        +0 -1: wait
        +1 -1: wait
        +1 -1: Some tests failed.""");
  });
}

final _prefixLength = "XX:XX ".length;

void _expectReport(String tests, String expected) {
  var dart = """
import 'dart:async';

import 'package:unittest/unittest.dart';

void main() {
  var declarer = Zone.current[#unittest.declarer];
$tests
}
""";

  expect(withTempDir((path) {
    new File(p.join(path, "test.dart")).writeAsStringSync(dart);
    var result = runUnittest(["test.dart"], workingDirectory: path);

    // Convert CRs into newlines, remove excess trailing whitespace, and trim
    // off timestamps.
    var actual = result.stdout.trim().split(new RegExp(r"[\r\n]")).map((line) {
      if (line.startsWith("  ") || line.isEmpty) return line.trimRight();
      return line.trim().substring(_prefixLength);
    }).join("\n");

    // Un-indent the expected string.
    var indentation = expected.indexOf(new RegExp("[^ ]"));
    expected = expected.split("\n").map((line) {
      if (line.isEmpty) return line;
      return line.substring(indentation);
    }).join("\n");

    expect(actual, equals(expected));
  }), completes);
}
