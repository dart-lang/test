// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:convert';
import 'dart:io';

import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../io.dart';

void main() {
  group('with the --coverage flag,', () {
    test('gathers coverage for VM tests', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test 1", () {
            expect(true, isTrue);
          });
        }
      ''').create();

      final coverageDirectory =
          Directory(p.join(Directory.current.path, 'test_coverage'));
      expect(await coverageDirectory.exists(), isFalse,
          reason:
              'Coverage directory exists, cannot safely run coverage tests. Delete the ${coverageDirectory.path} directory to fix.');

      var test =
          await runTest(['--coverage', coverageDirectory.path, 'test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      final coverageFile =
          File(p.join(coverageDirectory.path, 'test.dart.vm.json'));
      final coverage = await coverageFile.readAsString();
      final jsonCoverage = json.decode(coverage);
      expect(jsonCoverage['coverage'], isNotEmpty);

      await coverageDirectory.delete(recursive: true);
    });
  });
}
