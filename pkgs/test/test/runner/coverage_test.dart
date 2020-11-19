// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.7

@TestOn('vm')

import 'dart:convert';
import 'dart:io';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

import '../io.dart';

void main() {
  group('with the --coverage flag,', () {
    Directory coverageDirectory;

    Future<void> _validateCoverage(
        TestProcess test, String coveragePath) async {
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      final coverageFile = File(p.join(coverageDirectory.path, coveragePath));
      final coverage = await coverageFile.readAsString();
      final jsonCoverage = json.decode(coverage);
      expect(jsonCoverage['coverage'], isNotEmpty);
    }

    setUp(() async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test 1", () {
            expect(true, isTrue);
          });
        }
      ''').create();

      coverageDirectory =
          await Directory.systemTemp.createTemp('test_coverage');
    });

    tearDown(() async {
      await coverageDirectory.delete(recursive: true);
    });

    test('gathers coverage for VM tests', () async {
      var test =
          await runTest(['--coverage', coverageDirectory.path, 'test.dart']);
      await _validateCoverage(test, 'test.dart.vm.json');
    });

    test('gathers coverage for Chrome tests', () async {
      var test = await runTest(
          ['--coverage', coverageDirectory.path, 'test.dart', '-p', 'chrome']);
      await _validateCoverage(test, 'test.dart.chrome.json');
    });
  });
}
