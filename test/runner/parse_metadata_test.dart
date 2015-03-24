// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unittest/unittest.dart';
import 'package:unittest/src/runner/parse_metadata.dart';

String _sandbox;
String _path;

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('unittest_').path;
    _path = p.join(_sandbox, "test.dart");
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("returns empty metadata for an empty file", () {
    new File(_path).writeAsStringSync("");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, isNull);
  });

  test("ignores irrelevant annotations", () {
    new File(_path).writeAsStringSync("@Fblthp\n@Fblthp.foo\nlibrary foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, isNull);
  });

  test("parses a valid annotation", () {
    new File(_path).writeAsStringSync("@TestOn('foo')\nlibrary foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, equals("foo"));
  });

  test("parses a prefixed annotation", () {
    new File(_path).writeAsStringSync(
        "@foo.TestOn('foo')\n"
        "import 'package:unittest/unittest.dart' as foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, equals("foo"));
  });

  test("ignores a constructor named TestOn", () {
    new File(_path).writeAsStringSync("@foo.TestOn('foo')\nlibrary foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, isNull);
  });

  group("throws an error for", () {
    test("a named constructor", () {
      new File(_path).writeAsStringSync("@TestOn.name('foo')\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });

    test("no argument list", () {
      new File(_path).writeAsStringSync("@TestOn\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });

    test("an empty argument list", () {
      new File(_path).writeAsStringSync("@TestOn()\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });

    test("a named argument", () {
      new File(_path).writeAsStringSync(
          "@TestOn(expression: 'foo')\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });

    test("multiple arguments", () {
      new File(_path).writeAsStringSync("@TestOn('foo', 'bar')\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });

    test("a non-string argument", () {
      new File(_path).writeAsStringSync("@TestOn(123)\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });

    test("multiple @TestOns", () {
      new File(_path).writeAsStringSync(
          "@TestOn('foo')\n@TestOn('bar')\nlibrary foo;");
      expect(() => parseMetadata(_path), throwsFormatException);
    });
  });
}