// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Timeout.factor(2)
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

final _slowSuite = '''
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:test/test.dart';

void main() {
  test('slow suite', () {
    File('slow_suite_done.txt').writeAsStringSync('done');
    expect(AnalysisContext, isNotNull);
  });
}
''';

final _fastSuite = '''
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('fast suite waits for slow suite', () async {
    final sw = Stopwatch()..start();
    while (!File('slow_suite_done.txt').existsSync()) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (sw.elapsed > const Duration(seconds: 30)) {
        fail('Timed out waiting for slow suite');
      }
    }
  });
}
''';

void main() {
  setUpAll(() async {
    await precompileTestExecutable();
  });

  group('multiplatform runner', () {
    test('can run multiple vm exe suites concurrently', () async {
      await d.file('slow_test.dart', _slowSuite).create();
      await d.file('fast_test.dart', _fastSuite).create();
      var test = await runTest(
        ['slow_test.dart', 'fast_test.dart', '-p', 'vm', '-c', 'exe'],
        concurrency: 2,
        forwardStdio: true,
        reporter: 'expanded',
      );

      expect(test.stdout, emitsThrough(contains('All tests passed!')));
      await test.shouldExit(0);
    });

    test('can run chrome and vm exe suites concurrently', () async {
      await d.file('slow_test.dart', _slowSuite).create();
      await d.file('fast_test.dart', _fastSuite).create();
      var test = await runTest(
        [
          'slow_test.dart',
          'fast_test.dart',
          '-p',
          'chrome,vm',
          '-c',
          'dart2js,exe',
        ],
        concurrency: 4,
        forwardStdio: true,
        reporter: 'expanded',
      );

      expect(test.stdout, emitsThrough(contains('All tests passed!')));
      await test.shouldExit(0);
    }, tags: 'chrome');

    test(
      'can run chrome and vm cli suites concurrently',
      () async {
        await d.file('slow_test.dart', _slowSuite).create();
        await d.file('fast_test.dart', _fastSuite).create();
        var test = await runTest(
          [
            'slow_test.dart',
            'fast_test.dart',
            '-p',
            'chrome,vm',
            '-c',
            'dart2js,cli',
          ],
          concurrency: 4,
          forwardStdio: true,
          reporter: 'expanded',
        );

        expect(test.stdout, emitsThrough(contains('All tests passed!')));
        await test.shouldExit(0);
      },
      tags: 'chrome',
      skip: supportsCliCompiler ? null : 'SDK too old',
    );
  });
}
