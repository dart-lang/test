// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as term_glyph;
import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  group('create()', () {
    test('creates a directory and its contents', () async {
      await d.dir('dir', [
        d.dir('subdir', [
          d.file('subfile1.txt', 'subcontents1'),
          d.file('subfile2.txt', 'subcontents2')
        ]),
        d.file('file1.txt', 'contents1'),
        d.file('file2.txt', 'contents2')
      ]).create();

      expect(File(p.join(d.sandbox, 'dir', 'file1.txt')).readAsString(),
          completion(equals('contents1')));
      expect(File(p.join(d.sandbox, 'dir', 'file2.txt')).readAsString(),
          completion(equals('contents2')));
      expect(
          File(p.join(d.sandbox, 'dir', 'subdir', 'subfile1.txt'))
              .readAsString(),
          completion(equals('subcontents1')));
      expect(
          File(p.join(d.sandbox, 'dir', 'subdir', 'subfile2.txt'))
              .readAsString(),
          completion(equals('subcontents2')));
    });

    test('works if the directory already exists', () async {
      await d.dir('dir').create();
      await d.dir('dir', [d.file('name.txt', 'contents')]).create();

      expect(File(p.join(d.sandbox, 'dir', 'name.txt')).readAsString(),
          completion(equals('contents')));
    });
  });

  group('validate()', () {
    test('completes successfully if the filesystem matches the descriptor',
        () async {
      var dirPath = p.join(d.sandbox, 'dir');
      var subdirPath = p.join(dirPath, 'subdir');
      await Directory(subdirPath).create(recursive: true);
      await File(p.join(dirPath, 'file1.txt')).writeAsString('contents1');
      await File(p.join(dirPath, 'file2.txt')).writeAsString('contents2');
      await File(p.join(subdirPath, 'subfile1.txt'))
          .writeAsString('subcontents1');
      await File(p.join(subdirPath, 'subfile2.txt'))
          .writeAsString('subcontents2');

      await d.dir('dir', [
        d.dir('subdir', [
          d.file('subfile1.txt', 'subcontents1'),
          d.file('subfile2.txt', 'subcontents2')
        ]),
        d.file('file1.txt', 'contents1'),
        d.file('file2.txt', 'contents2')
      ]).validate();
    });

    test("fails if the directory doesn't exist", () async {
      var dirPath = p.join(d.sandbox, 'dir');
      await Directory(dirPath).create();
      await File(p.join(dirPath, 'file1.txt')).writeAsString('contents1');
      await File(p.join(dirPath, 'file2.txt')).writeAsString('contents2');

      expect(
          d.dir('dir', [
            d.dir('subdir', [
              d.file('subfile1.txt', 'subcontents1'),
              d.file('subfile2.txt', 'subcontents2')
            ]),
            d.file('file1.txt', 'contents1'),
            d.file('file2.txt', 'contents2')
          ]).validate(),
          throwsA(toString(
              equals('Directory not found: "${p.join('dir', 'subdir')}".'))));
    });

    test('emits an error for each child that fails to validate', () async {
      var dirPath = p.join(d.sandbox, 'dir');
      var subdirPath = p.join(dirPath, 'subdir');
      await Directory(subdirPath).create(recursive: true);
      await File(p.join(dirPath, 'file1.txt')).writeAsString('contents1');
      await File(p.join(subdirPath, 'subfile2.txt'))
          .writeAsString('subwrongtents2');

      var errors = 0;
      var controller = StreamController<String>();
      runZonedGuarded(() {
        d.dir('dir', [
          d.dir('subdir', [
            d.file('subfile1.txt', 'subcontents1'),
            d.file('subfile2.txt', 'subcontents2')
          ]),
          d.file('file1.txt', 'contents1'),
          d.file('file2.txt', 'contents2')
        ]).validate();
      },
          expectAsync2((error, _) {
            errors++;
            controller.add(error.toString());
            if (errors == 3) controller.close();
          }, count: 3));

      expect(
          controller.stream.toList(),
          completion(allOf([
            contains(
                'File not found: "${p.join('dir', 'subdir', 'subfile1.txt')}".'),
            contains('File not found: "${p.join('dir', 'file2.txt')}".'),
            contains(
                startsWith('File "${p.join('dir', 'subdir', 'subfile2.txt')}" '
                    'should contain:')),
          ])));
    });
  });

  group('load()', () {
    test('loads a file', () {
      var dir = d.dir('dir',
          [d.file('name.txt', 'contents'), d.file('other.txt', 'wrong')]);
      expect(utf8.decodeStream(dir.load('name.txt')),
          completion(equals('contents')));
    });

    test('loads a deeply-nested file', () {
      var dir = d.dir('dir', [
        d.dir('subdir',
            [d.file('name.txt', 'subcontents'), d.file('other.txt', 'wrong')]),
        d.dir('otherdir', [d.file('other.txt', 'wrong')]),
        d.file('name.txt', 'contents')
      ]);

      expect(utf8.decodeStream(dir.load('subdir/name.txt')),
          completion(equals('subcontents')));
    });

    test('fails to load a nested directory', () {
      var dir = d.dir('dir', [
        d.dir('subdir', [
          d.dir('subsubdir', [d.file('name.txt', 'subcontents')])
        ]),
        d.file('name.txt', 'contents')
      ]);

      expect(
          dir.load('subdir/subsubdir').toList(),
          throwsA(toString(equals('Couldn\'t find a file descriptor named '
              '"subsubdir" within "dir/subdir".'))));
    });

    test('fails to load an absolute path', () {
      var dir = d.dir('dir', [d.file('name.txt', 'contents')]);
      expect(() => dir.load('/name.txt'), throwsArgumentError);
    });

    test("fails to load '..'", () {
      var dir = d.dir('dir', [d.file('name.txt', 'contents')]);
      expect(() => dir.load('..'), throwsArgumentError);
    });

    test("fails to load a file that doesn't exist", () {
      var dir = d.dir('dir', [
        d.dir('subdir', [d.file('name.txt', 'contents')])
      ]);

      expect(
          dir.load('subdir/not-name.txt').toList(),
          throwsA(toString(equals('Couldn\'t find a file descriptor named '
              '"not-name.txt" within "dir/subdir".'))));
    });

    test('fails to load a file that exists multiple times', () {
      var dir = d.dir('dir', [
        d.dir('subdir',
            [d.file('name.txt', 'contents'), d.file('name.txt', 'contents')])
      ]);

      expect(
          dir.load('subdir/name.txt').toList(),
          throwsA(toString(equals('Found multiple file descriptors named '
              '"name.txt" within "dir/subdir".'))));
    });

    test('loads a file next to a subdirectory with the same name', () {
      var dir = d.dir('dir', [
        d.file('name', 'contents'),
        d.dir('name', [d.file('subfile', 'contents')])
      ]);

      expect(
          utf8.decodeStream(dir.load('name')), completion(equals('contents')));
    });
  });

  group('describe()', () {
    bool oldAscii;
    setUpAll(() {
      oldAscii = term_glyph.ascii;
      term_glyph.ascii = true;
    });

    tearDownAll(() {
      term_glyph.ascii = oldAscii;
    });

    test('lists the contents of the directory', () {
      var dir = d.dir('dir',
          [d.file('file1.txt', 'contents1'), d.file('file2.txt', 'contents2')]);

      expect(
          dir.describe(),
          equals('dir\n'
              '+-- file1.txt\n'
              "'-- file2.txt"));
    });

    test('lists the contents of nested directories', () {
      var dir = d.dir('dir', [
        d.file('file1.txt', 'contents1'),
        d.dir('subdir', [
          d.file('subfile1.txt', 'subcontents1'),
          d.file('subfile2.txt', 'subcontents2'),
          d.dir('subsubdir', [d.file('subsubfile.txt', 'subsubcontents')])
        ]),
        d.file('file2.txt', 'contents2')
      ]);

      expect(
          dir.describe(),
          equals('dir\n'
              '+-- file1.txt\n'
              '+-- subdir\n'
              '|   +-- subfile1.txt\n'
              '|   +-- subfile2.txt\n'
              "|   '-- subsubdir\n"
              "|       '-- subsubfile.txt\n"
              "'-- file2.txt"));
    });

    test('with no contents returns the directory name', () {
      expect(d.dir('dir').describe(), equals('dir'));
    });
  });

  group('fromFilesystem()', () {
    test('creates a descriptor based on the physical filesystem', () async {
      var dir = d.dir('dir', [
        d.dir('subdir', [
          d.file('subfile1.txt', 'subcontents1'),
          d.file('subfile2.txt', 'subcontents2')
        ]),
        d.file('file1.txt', 'contents1'),
        d.file('file2.txt', 'contents2')
      ]);

      await dir.create();
      var descriptor =
          d.DirectoryDescriptor.fromFilesystem('dir', p.join(d.sandbox, 'dir'));
      await descriptor.create(p.join(d.sandbox, 'dir2'));
      await dir.validate(p.join(d.sandbox, 'dir2'));
    });

    test('ignores hidden files', () async {
      await d.dir('dir', [
        d.dir('subdir', [
          d.file('subfile1.txt', 'subcontents1'),
          d.file('.hidden', 'subcontents2')
        ]),
        d.file('file1.txt', 'contents1'),
        d.file('.DS_Store', 'contents2')
      ]).create();

      var descriptor = d.DirectoryDescriptor.fromFilesystem(
          'dir2', p.join(d.sandbox, 'dir'));
      await descriptor.create();

      await d.dir('dir2', [
        d.dir('subdir',
            [d.file('subfile1.txt', 'subcontents1'), d.nothing('.hidden')]),
        d.file('file1.txt', 'contents1'),
        d.nothing('.DS_Store')
      ]).validate();
    });
  });

  test('io refers to the directory within the sandbox', () {
    expect(d.file('dir').io.path, equals(p.join(d.sandbox, 'dir')));
  });
}
