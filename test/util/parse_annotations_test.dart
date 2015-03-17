// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/src/generated/ast.dart';
import 'package:path/path.dart' as p;
import 'package:unittest/unittest.dart';
import 'package:unittest/src/util/dart.dart';

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

  test("with an empty file", () {
    new File(_path).writeAsStringSync("");

    var annotations = parseAnnotations(_path);
    expect(annotations, isEmpty);
  });

  test("before a library tag", () {
    new File(_path).writeAsStringSync("@Annotation()\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name.name, equals('Annotation'));
    expect(annotations.first.arguments.arguments, isEmpty);
  });

  test("before an import", () {
    new File(_path).writeAsStringSync("@Annotation()\nimport 'foo';");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name.name, equals('Annotation'));
    expect(annotations.first.arguments.arguments, isEmpty);
  });

  test("multiple annotations", () {
    new File(_path).writeAsStringSync(
        "@Annotation1() @Annotation2()\n@Annotation3()\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(3));
    expect(annotations[0].name.name, equals('Annotation1'));
    expect(annotations[0].arguments.arguments, isEmpty);
    expect(annotations[1].name.name, equals('Annotation2'));
    expect(annotations[1].arguments.arguments, isEmpty);
    expect(annotations[2].name.name, equals('Annotation3'));
    expect(annotations[2].arguments.arguments, isEmpty);
  });

  test("with no arguments", () {
    new File(_path).writeAsStringSync("@Annotation\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name.name, equals('Annotation'));
    expect(annotations.first.arguments, isNull);
  });

  test("with positional arguments", () {
    new File(_path).writeAsStringSync("@Annotation('foo', 12)\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name.name, equals('Annotation'));
    var args = annotations.first.arguments.arguments;
    expect(args, hasLength(2));
    expect(args[0], new isInstanceOf<StringLiteral>());
    expect(args[0].stringValue, equals('foo'));
    expect(args[1], new isInstanceOf<IntegerLiteral>());
    expect(args[1].value, equals(12));
  });

  test("with named arguments", () {
    new File(_path).writeAsStringSync(
        "@Annotation(name1: 'foo', name2: 12)\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name.name, equals('Annotation'));
    var args = annotations.first.arguments.arguments;
    expect(args, hasLength(2));
    expect(args[0], new isInstanceOf<NamedExpression>());
    expect(args[0].expression, new isInstanceOf<StringLiteral>());
    expect(args[0].expression.stringValue, equals('foo'));
    expect(args[1], new isInstanceOf<IntegerLiteral>());
    expect(args[1].expression, new isInstanceOf<IntegerLiteral>());
    expect(args[1].expression.value, equals(12));
  });

  test("with a prefix/named constructor", () {
    new File(_path).writeAsStringSync("@Annotation.name()\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name, new isInstanceOf<PrefixedIdentifier>());
    expect(annotations.first.name.prefix.name, equals('Annotation'));
    expect(annotations.first.name.identifier.name, equals('name'));
    expect(annotations.first.constructorName, isNull);
    expect(annotations.first.arguments.arguments, isEmpty);
  });

  test("with a prefix and named constructor", () {
    new File(_path).writeAsStringSync(
        "@prefix.Annotation.name()\nlibrary foo;");

    var annotations = parseAnnotations(_path);
    expect(annotations, hasLength(1));
    expect(annotations.first.name, new isInstanceOf<PrefixedIdentifier>());
    expect(annotations.first.name.prefix.name, equals('prefix'));
    expect(annotations.first.name.identifier.name, equals('Annotation'));
    expect(annotations.first.constructorName.name, equals('name'));
    expect(annotations.first.arguments.arguments, isEmpty);
  });

  test("annotations after the first directive are ignored", () {
    new File(_path).writeAsStringSync(
        "library foo;\n@prefix.Annotation.name()");

    expect(parseAnnotations(_path), isEmpty);
  });

  group("comments are ignored", () {
    test("before an annotation", () {
      new File(_path).writeAsStringSync(
          "/* comment */@Annotation()\nlibrary foo;");

      var annotations = parseAnnotations(_path);
      expect(annotations, hasLength(1));
      expect(annotations.first.name.name, equals('Annotation'));
      expect(annotations.first.arguments.arguments, isEmpty);
    });

    test("within an annotation", () {
      new File(_path).writeAsStringSync(
          "@Annotation(/* comment */)\nlibrary foo;");

      var annotations = parseAnnotations(_path);
      expect(annotations, hasLength(1));
      expect(annotations.first.name.name, equals('Annotation'));
      expect(annotations.first.arguments.arguments, isEmpty);
    });

    test("after an annotation", () {
      new File(_path).writeAsStringSync(
          "@Annotation()/* comment */\nlibrary foo;");

      var annotations = parseAnnotations(_path);
      expect(annotations, hasLength(1));
      expect(annotations.first.name.name, equals('Annotation'));
      expect(annotations.first.arguments.arguments, isEmpty);
    });

    test("between annotations", () {
      new File(_path).writeAsStringSync(
          "@Annotation1()/* comment */@Annotation2()\nlibrary foo;");

      var annotations = parseAnnotations(_path);
      expect(annotations, hasLength(2));
      expect(annotations[0].name.name, equals('Annotation1'));
      expect(annotations[0].arguments.arguments, isEmpty);
      expect(annotations[1].name.name, equals('Annotation2'));
      expect(annotations[1].arguments.arguments, isEmpty);
    });
  });
}
