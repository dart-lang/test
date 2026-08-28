// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Timeout.factor(2)
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

final _test = '''
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''';

void main() {
  setUpAll(() async {
    await precompileTestExecutable();
  });

  group('multiplatform runner', () {
    test('can run chrome and vm exe suites concurrently', () async {
      for (var i = 1; i <= 3; i++) {
        await d.file('test$i.dart', _test).create();
      }
      var test = await runTest([
        for (var i = 1; i <= 3; i++) 'test$i.dart',
        '-p',
        'chrome,vm',
        '-c',
        'dart2js,exe',
      ]);

      expect(test.stdout, emitsThrough(contains('+6: All tests passed!')));
      await test.shouldExit(0);
    }, tags: 'chrome');

    test(
      'can run chrome and vm cli suites concurrently',
      () async {
        for (var i = 1; i <= 3; i++) {
          await d.file('test$i.dart', _test).create();
        }
        var test = await runTest([
          for (var i = 1; i <= 3; i++) 'test$i.dart',
          '-p',
          'chrome,vm',
          '-c',
          'dart2js,cli',
        ]);

        expect(test.stdout, emitsThrough(contains('+6: All tests passed!')));
        await test.shouldExit(0);
      },
      tags: 'chrome',
      skip: supportsCliCompiler ? null : 'SDK too old',
    );
  });
}
