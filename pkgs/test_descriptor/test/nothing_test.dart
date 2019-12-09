// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  test('create() does nothing', () async {
    await d.nothing('foo').create();
    expect(File(p.join(d.sandbox, 'foo')).exists(), completion(isFalse));
    expect(Directory(p.join(d.sandbox, 'foo')).exists(), completion(isFalse));
  });

  group('validate()', () {
    test("succeeds if nothing's there", () async {
      await d.nothing('foo').validate();
    });

    test("fails if there's a file", () async {
      await d.file('name.txt', 'contents').create();
      expect(
          d.nothing('name.txt').validate(),
          throwsA(toString(equals(
              'Expected nothing to exist at "name.txt", but found a file.'))));
    });

    test("fails if there's a directory", () async {
      await d.dir('dir').create();
      expect(
          d.nothing('dir').validate(),
          throwsA(toString(equals(
              'Expected nothing to exist at "dir", but found a directory.'))));
    });

    test("fails if there's a broken link", () async {
      await Link(p.join(d.sandbox, 'link')).create('nonexistent');
      expect(
          d.nothing('link').validate(),
          throwsA(toString(equals(
              'Expected nothing to exist at "link", but found a link.'))));
    });
  });
}
