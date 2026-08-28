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
      await d.file('test1.dart', _test).create();
      await d.file('test2.dart', _test).create();
      var test = await runTest([
        'test1.dart',
        'test2.dart',
        '-p',
        'chrome,vm',
        '-c',
        'dart2js,exe',
      ]);

      expect(test.stdout, emitsThrough(contains('+4: All tests passed!')));
      await test.shouldExit(0);
    }, tags: 'chrome');

    test(
      'can run chrome and vm cli suites concurrently',
      () async {
        await d.file('test1.dart', _test).create();
        await d.file('test2.dart', _test).create();
        var test = await runTest([
          'test1.dart',
          'test2.dart',
          '-p',
          'chrome,vm',
          '-c',
          'dart2js,cli',
        ]);

        expect(test.stdout, emitsThrough(contains('+4: All tests passed!')));
        await test.shouldExit(0);
      },
      tags: 'chrome',
      skip: supportsCliCompiler ? null : 'SDK too old',
    );
  });
}
