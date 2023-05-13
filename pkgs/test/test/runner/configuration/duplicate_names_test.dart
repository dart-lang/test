// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  group('duplicate names', () {
    group('can be disabled for', () {
      test('groups', () async {
        await d
            .file('dart_test.yaml',
                jsonEncode({'allow_duplicate_test_names': false}))
            .create();

        await d.file('test.dart', _identicalGroupnames).create();

        var test = await runTest([
          'test.dart',
          '--configuration',
          p.join(d.sandbox, 'dart_test.yaml')
        ]);

        expect(
            test.stdout,
            emitsThrough(contains(
                'A test with the name "identical name" was already declared.')));

        await test.shouldExit(1);
      });
      test('tests', () async {
        await d
            .file('dart_test.yaml',
                jsonEncode({'allow_duplicate_test_names': false}))
            .create();

        await d.file('test.dart', _identicalTestNames).create();

        var test = await runTest([
          'test.dart',
          '--configuration',
          p.join(d.sandbox, 'dart_test.yaml')
        ]);

        expect(
            test.stdout,
            emitsThrough(contains(
                'A test with the name "identical name" was already declared.')));

        await test.shouldExit(1);
      });
    });
    group('are allowed by default for', () {
      test('groups', () async {
        await d.file('test.dart', _identicalGroupnames).create();

        var test = await runTest(
          ['test.dart'],
        );

        expect(test.stdout, emitsThrough(contains('All tests passed!')));

        await test.shouldExit(0);
      });
      test('tests', () async {
        await d.file('test.dart', _identicalTestNames).create();

        var test = await runTest(
          ['test.dart'],
        );

        expect(test.stdout, emitsThrough(contains('All tests passed!')));

        await test.shouldExit(0);
      });
    });
  });
}

const _identicalTestNames = '''
import 'package:test/test.dart';

void main() {
  test('identical name', () {});
  test('identical name', () {});
}
''';
const _identicalGroupnames = '''
import 'package:test/test.dart';

void main() {
  group('identical name', () {
    test('foo', () {});
  });
  group('identical name', () {
    test('bar', () {});
  });
}
''';
