// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  group('fails gracefully if a test file calls exit(0)', () {
    setUp(() async {
      await d.file('test.dart', '''
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('exits', () {
    exit(0);
  });
}
''').create();
    });

    test('in a VM test', () async {
      var test = await runTest(['test.dart']);

      expect(test.stdout, containsInOrder(['exit(0) was called.']));
      await test.shouldExit(1);
    });

    test('in a native test', () async {
      var test = await runTest(['--compiler', 'exe', 'test.dart']);

      expect(test.stdout, containsInOrder(['exit(0) was called.']));
      await test.shouldExit(1);
    });
  });
}
