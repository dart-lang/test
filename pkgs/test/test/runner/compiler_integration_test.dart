// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Timeout.factor(2)
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

String _testSuite(int numTests) {
  final sb = StringBuffer('''
import 'package:test/test.dart';

void main() {
  test('primary', () async {
    await Future<void>.delayed(const Duration(seconds: 2));
  });
''');
  for (var i = 0; i < numTests; i++) {
    sb.writeln("  test('dummy $i', () { expect($i, $i); });");
  }
  sb.writeln('}');
  return sb.toString();
}

void main() {
  setUpAll(() async {
    await precompileTestExecutable();
  });

  group('multiplatform runner', () {
    test('can run multiple vm exe suites concurrently', () async {
      final counts = [1, 50, 100, 200, 1, 50, 100, 200, 1, 50, 100, 200];
      for (var i = 0; i < counts.length; i++) {
        await d.file('test$i.dart', _testSuite(counts[i])).create();
      }
      var test = await runTest([
        for (var i = 0; i < counts.length; i++) 'test$i.dart',
        '-p',
        'vm',
        '-c',
        'exe',
      ], concurrency: 4, forwardStdio: true, reporter: 'expanded');

      expect(test.stdout, emitsThrough(contains('All tests passed!')));
      await test.shouldExit(0);
    });

    test('can run chrome and vm exe suites concurrently', () async {
      final counts = [1, 50, 100, 200];
      for (var i = 0; i < counts.length; i++) {
        await d.file('test$i.dart', _testSuite(counts[i])).create();
      }
      var test = await runTest([
        for (var i = 0; i < counts.length; i++) 'test$i.dart',
        '-p',
        'chrome,vm',
        '-c',
        'dart2js,exe',
      ], concurrency: 8);

      expect(test.stdout, emitsThrough(contains('All tests passed!')));
      await test.shouldExit(0);
    }, tags: 'chrome');

    test(
      'can run chrome and vm cli suites concurrently',
      () async {
        final counts = [1, 50, 100, 200];
        for (var i = 0; i < counts.length; i++) {
          await d.file('test$i.dart', _testSuite(counts[i])).create();
        }
        var test = await runTest([
          for (var i = 0; i < counts.length; i++) 'test$i.dart',
          '-p',
          'chrome,vm',
          '-c',
          'dart2js,cli',
        ], concurrency: 8);

        expect(test.stdout, emitsThrough(contains('All tests passed!')));
        await test.shouldExit(0);
      },
      tags: 'chrome',
      skip: supportsCliCompiler ? null : 'SDK too old',
    );
  });
}
