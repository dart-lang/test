// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  group('validate()', () {
    test("succeeds if there's a file matching the pattern and the child",
        () async {
      await d.file('foo', 'blap').create();
      await d.filePattern(RegExp(r'f..'), 'blap').validate();
    });

    test("succeeds if there's a directory matching the pattern and the child",
        () async {
      await d.dir('foo', [d.file('bar', 'baz')]).create();

      await d.dirPattern(RegExp(r'f..'), [d.file('bar', 'baz')]).validate();
    });

    test(
        'succeeds if multiple files match the pattern but only one matches '
        'the child entry', () async {
      await d.file('foo', 'blap').create();
      await d.file('fee', 'blak').create();
      await d.file('faa', 'blut').create();

      await d.filePattern(RegExp(r'f..'), 'blap').validate();
    });

    test("fails if there's no file matching the pattern", () {
      expect(
          d.filePattern(RegExp(r'f..'), 'bar').validate(),
          throwsA(
              toString(equals('No entries found in sandbox matching /f../.'))));
    });

    test("fails if there's a file matching the pattern but not the entry",
        () async {
      await d.file('foo', 'bap').create();
      expect(d.filePattern(RegExp(r'f..'), 'bar').validate(),
          throwsA(toString(startsWith('File "foo" should contain:'))));
    });

    test("fails if there's a dir matching the pattern but not the entry",
        () async {
      await d.dir('foo', [d.file('bar', 'bap')]).create();

      expect(d.dirPattern(RegExp(r'f..'), [d.file('bar', 'baz')]).validate(),
          throwsA(toString(startsWith('File "foo/bar" should contain:'))));
    });

    test(
        'fails if there are multiple files matching the pattern and the child '
        'entry', () async {
      await d.file('foo', 'bar').create();
      await d.file('fee', 'bar').create();
      await d.file('faa', 'bar').create();
      expect(
          d.filePattern(RegExp(r'f..'), 'bar').validate(),
          throwsA(toString(startsWith(
              'Multiple valid entries found in sandbox matching /f../:'))));
    });
  });
}
