// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  group('compilers', () {
    test('uses specified compilers for supporting platforms', () async {
      await d
          .file(
              'dart_test.yaml',
              jsonEncode({
                'compilers': ['source']
              }))
          .create();

      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      ''').create();

      var test = await runTest(['-p', 'chrome,vm', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '+0: [Chrome, Dart2Js]',
            '+1: [VM, Source]',
            '+2: All tests passed!',
          ]));
      await test.shouldExit(0);
    });

    test('supports platform selectors with compilers', () async {
      await d
          .file(
              'dart_test.yaml',
              jsonEncode({
                'compilers': ['vm:source', 'browser:kernel']
              }))
          .create();

      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test", () {});
        }
      ''').create();

      var test = await runTest(['-p', 'chrome,vm', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '+0: [Chrome, Dart2Js]',
            '+1: [VM, Source]',
            '+2: All tests passed!',
          ]));
      await test.shouldExit(0);
    });
  });
}
