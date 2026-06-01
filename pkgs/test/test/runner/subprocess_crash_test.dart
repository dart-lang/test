// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  for (var compiler in ['exe', 'cli']) {
    test(
      'gracefully handles an early test suite exit with the $compiler compiler',
      () async {
        await d.file('test.dart', '''
        import 'dart:io';

        import 'package:test/test.dart';

        void main() {
          test('runs', () {});
          test('exits', () {
            exit(0);
          });
        }''').create();

        var test = await runTest(['--compiler', compiler, 'test.dart']);
        expect(
          test.stdout,
          containsInOrder([
            '+1: [VM, ${compiler == 'exe' ? 'Exe' : 'Cli'}] exits - did not complete [E]',
            '+1: Some tests failed.',
          ]),
        );
        await test.shouldExit(1);
      },
      skip: compiler == 'cli' && !supportsCliCompiler
          ? 'Dart version does not support build cli'
          : null,
    );
  }
}
