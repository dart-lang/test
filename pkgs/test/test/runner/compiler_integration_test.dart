// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Timeout.factor(2)
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(() async {
    await precompileTestExecutable();
  });

  group('multiplatform runner', () {
    test('can run multiple vm exe suites concurrently', () async {
      await d.file('fast_test.dart', '''
import 'package:test/test.dart';

void main() {
  test('quick test', () {
    expect(1, equals(1));
  });
}
''').create();

      await d.file('slow_test.dart', '''
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:test/test.dart';

void main() {
  test('slow test', () async {
    expect(AnalysisContext, isNotNull);
    await Future<void>.delayed(const Duration(seconds: 15));
  });
}
''').create();

      var test = await runTest(
        [
          'fast_test.dart',
          'slow_test.dart',
          '-p',
          'vm',
          '-c',
          'exe',
          '--suite-load-timeout=8s',
        ],
        concurrency: 2,
        forwardStdio: true,
        reporter: 'expanded',
      );

      expect(test.stdout, emitsThrough(contains('All tests passed!')));
      await test.shouldExit(0);
    });

    test('can run vm exe and chrome suites concurrently', () async {
      await d.file('vm_test.dart', '''
@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:test/test.dart';

void main() {
  test('vm test', () {
    expect(AnalysisContext, isNotNull);
  });
}
''').create();

      await d.file('chrome_test.dart', '''
@TestOn('browser')
library;

import 'package:test/test.dart';

void main() {
  test('chrome test', () {
    expect(1, equals(1));
  });
}
''').create();

      var test = await runTest(
        [
          'vm_test.dart',
          'chrome_test.dart',
          '-p',
          'vm,chrome',
          '-c',
          'exe,dart2js',
        ],
        concurrency: 4,
        forwardStdio: true,
        reporter: 'expanded',
      );

      expect(test.stdout, emitsThrough(contains('All tests passed!')));
      await test.shouldExit(0);
    }, tags: 'chrome');

    test(
      'can run vm cli and chrome suites concurrently',
      () async {
        await d.file('vm_test.dart', '''
@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:test/test.dart';

void main() {
  test('vm test', () {
    expect(AnalysisContext, isNotNull);
  });
}
''').create();

        await d.file('chrome_test.dart', '''
@TestOn('browser')
library;

import 'package:test/test.dart';

void main() {
  test('chrome test', () {
    expect(1, equals(1));
  });
}
''').create();

        var test = await runTest(
          [
            'vm_test.dart',
            'chrome_test.dart',
            '-p',
            'vm,chrome',
            '-c',
            'cli,dart2js',
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
