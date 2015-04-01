// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test/src/backend/platform_selector.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/runner/parse_metadata.dart';

String _sandbox;
String _path;

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('test_').path;
    _path = p.join(_sandbox, "test.dart");
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  test("returns empty metadata for an empty file", () {
    new File(_path).writeAsStringSync("");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, equals(PlatformSelector.all));
  });

  test("ignores irrelevant annotations", () {
    new File(_path).writeAsStringSync("@Fblthp\n@Fblthp.foo\nlibrary foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, equals(PlatformSelector.all));
  });

  test("parses a valid annotation", () {
    new File(_path).writeAsStringSync("@TestOn('vm')\nlibrary foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn.evaluate(TestPlatform.vm), isTrue);
    expect(metadata.testOn.evaluate(TestPlatform.chrome), isFalse);
  });

  test("parses a prefixed annotation", () {
    new File(_path).writeAsStringSync(
        "@foo.TestOn('vm')\n"
        "import 'package:test/test.dart' as foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn.evaluate(TestPlatform.vm), isTrue);
    expect(metadata.testOn.evaluate(TestPlatform.chrome), isFalse);
  });

  test("ignores a constructor named TestOn", () {
    new File(_path).writeAsStringSync("@foo.TestOn('foo')\nlibrary foo;");
    var metadata = parseMetadata(_path);
    expect(metadata.testOn, equals(PlatformSelector.all));
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