// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:matcher/expect.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test('uses the passed suite load timeout', () async {
    await d.file('test.dart', '''
      import 'dart:async';

      import 'package:test/test.dart';

      Future<void> main() async {
        await Future.delayed(Duration(seconds: 2));
        test('success', () {});
      }
    ''').create();

    var test = await runTest(['--suite-load-timeout=1s', 'test.dart']);
    expect(
      test.stdout,
      containsInOrder([
        'loading test.dart [E]',
        'Test timed out after 1 seconds.',
        '-1: Some tests failed.',
      ]),
    );
    await test.shouldExit(1);
  });
}
