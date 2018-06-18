// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  group("create()", () {
    test('creates a text file', () async {
      await d.file('name.txt', 'contents').create();

      expect(new File(p.join(d.sandbox, 'name.txt')).readAsString(),
          completion(equals('contents')));
    });

    test('creates a binary file', () async {
      await d.file('name.txt', [0, 1, 2, 3]).create();

      expect(new File(p.join(d.sandbox, 'name.txt')).readAsBytes(),
          completion(equals([0, 1, 2, 3])));
    });

    test('fails to create a matcher file', () async {
      expect(
          d.file('name.txt', contains('foo')).create(), throwsUnsupportedError);
    });

    test('overwrites an existing file', () async {
      await d.file('name.txt', 'contents1').create();
      await d.file('name.txt', 'contents2').create();

      expect(new File(p.join(d.sandbox, 'name.txt')).readAsString(),
          completion(equals('contents2')));
    });
  });

  group("validate()", () {
    test('succeeds if the filesystem matches a text descriptor', () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsString('contents');
      await d.file('name.txt', 'contents').validate();
    });

    test('succeeds if the filesystem matches a binary descriptor', () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsBytes([0, 1, 2, 3]);
      await d.file('name.txt', [0, 1, 2, 3]).validate();
    });

    test('succeeds if the filesystem matches a text matcher', () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsString('contents');
      await d.file('name.txt', contains('ent')).validate();
    });

    test('succeeds if the filesystem matches a binary matcher', () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsBytes([0, 1, 2, 3]);
      await new d.FileDescriptor.binaryMatcher('name.txt', contains(2))
          .validate();
    });

    test('succeeds if invalid UTF-8 matches a text matcher', () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsBytes([0xC3, 0x28]);
      await d.file('name.txt', isNot(isEmpty)).validate();
    });

    test("fails if the text contents don't match", () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsString('wrong');

      expect(d.file('name.txt', 'contents').validate(),
          throwsA(toString(startsWith('File "name.txt" should contain:'))));
    });

    test("fails if the binary contents don't match", () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsBytes([5, 4, 3, 2]);

      expect(
          d.file('name.txt', [0, 1, 2, 3]).validate(),
          throwsA(toString(equals(
              'File "name.txt" didn\'t contain the expected binary data.'))));
    });

    test("fails if the text contents don't match the matcher", () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsString('wrong');

      expect(
          d.file('name.txt', contains('ent')).validate(),
          throwsA(
              toString(startsWith('Invalid contents for file "name.txt":'))));
    });

    test("fails if the binary contents don't match the matcher", () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsBytes([5, 4, 3, 2]);

      expect(
          new d.FileDescriptor.binaryMatcher('name.txt', contains(1))
              .validate(),
          throwsA(
              toString(startsWith('Invalid contents for file "name.txt":'))));
    });

    test("fails if invalid UTF-8 doesn't match a text matcher", () async {
      await new File(p.join(d.sandbox, 'name.txt')).writeAsBytes([0xC3, 0x28]);
      expect(
          d.file('name.txt', isEmpty).validate(),
          throwsA(toString(allOf([
            startsWith('Invalid contents for file "name.txt":'),
            contains('�')
          ]))));
    });

    test("fails if there's no file", () {
      expect(d.file('name.txt', 'contents').validate(),
          throwsA(toString(equals('File not found: "name.txt".'))));
    });
  });

  group("reading", () {
    test("read() returns the contents of a text file as a string", () {
      expect(d.file('name.txt', 'contents').read(),
          completion(equals('contents')));
    });

    test("read() returns the contents of a binary file as a string", () {
      expect(d.file('name.txt', [0x68, 0x65, 0x6c, 0x6c, 0x6f]).read(),
          completion(equals('hello')));
    });

    test("read() fails for a matcher file", () {
      expect(d.file('name.txt', contains('hi')).read, throwsUnsupportedError);
    });

    test("readAsBytes() returns the contents of a text file as a byte stream",
        () {
      expect(UTF8.decodeStream(d.file('name.txt', 'contents').readAsBytes()),
          completion(equals('contents')));
    });

    test("readAsBytes() returns the contents of a binary file as a byte stream",
        () {
      expect(byteStreamToList(d.file('name.txt', [0, 1, 2, 3]).readAsBytes()),
          completion(equals([0, 1, 2, 3])));
    });

    test("readAsBytes() fails for a matcher file", () {
      expect(d.file('name.txt', contains('hi')).readAsBytes,
          throwsUnsupportedError);
    });
  });

  test("io refers to the file within the sandbox", () {
    expect(d.file('name.txt').io.path, equals(p.join(d.sandbox, 'name.txt')));
  });
}
