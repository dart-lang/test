// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:test/test.dart';

import '../../io.dart';

void main() {
  group('duplicate names', () {
    group('are not allowed by default for', () {
      for (var function in ['group', 'test']) {
        test('${function}s', () async {
          var testName = 'test';
          await d.file('test.dart', '''
          import 'package:test/test.dart';

          void main() {
            $function("$testName", () {});
            $function("$testName", () {});
          }
        ''').create();

          var test = await runTest(['test.dart']);

          expect(
              test.stdout,
              emitsThrough(contains(
                  'A test with the name "$testName" was already declared.')));

          await test.shouldExit(1);
        });
      }
    });
    group('can be enabled for ', () {
      for (var function in ['group', 'test']) {
        test('${function}s', () async {
          await d
              .file('dart_test.yaml',
                  jsonEncode({'allow_duplicate_test_names': true}))
              .create();

          var testName = 'test';
          await d.file('test.dart', '''
          import 'package:test/test.dart';

          void main() {
            $function("$testName", () {});
            $function("$testName", () {});

            // Needed so at least one test runs when testing groups.
            test('a test', () {
              expect(true, isTrue);
            });
          }
        ''').create();

          var test = await runTest(['test.dart'],
              environment: {'DART_TEST_CONFIG': 'global_test.yaml'});

          expect(test.stdout, emitsThrough(contains('All tests passed!')));

          await test.shouldExit(0);
        });
      }
    });
  });
}
