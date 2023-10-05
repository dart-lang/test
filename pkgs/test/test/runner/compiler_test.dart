// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
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
    await d.file('test.dart', _test).create();
  });

  group('--compiler', () {
    test(
        'uses the default compiler if none other is specified for the platform',
        () async {
      var test =
          await runTest(['test.dart', '-p', 'chrome,vm', '-c', 'dart2js']);

      expect(test.stdout, emitsThrough(contains('[Chrome, Dart2Js]')));
      expect(test.stdout, emitsThrough(contains('[VM, Kernel]')));
      expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
      await test.shouldExit(0);
    });

    test('runs all supported compiler and platform combinations', () async {
      var test = await runTest(
          ['test.dart', '-p', 'chrome,vm', '-c', 'dart2js,kernel,source']);

      expect(test.stdout, emitsThrough(contains('[Chrome, Dart2Js]')));
      expect(test.stdout, emitsThrough(contains('[VM, Kernel]')));
      expect(test.stdout, emitsThrough(contains('[VM, Source]')));
      expect(test.stdout, emitsThrough(contains('+3: All tests passed!')));
      await test.shouldExit(0);
    });

    test('supports platform selectors', () async {
      var test = await runTest(
          ['test.dart', '-p', 'vm', '-c', 'vm:source,browser:kernel']);

      expect(test.stdout, emitsThrough(contains('[VM, Source]')));
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });

    test(
        'will only run a given test once for each compiler, even if there are '
        'multiple matches', () async {
      var test =
          await runTest(['test.dart', '-p', 'vm', '-c', 'vm:source,source']);

      expect(test.stdout, emitsThrough(contains('[VM, Source]')));
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });

    test('fails on unknown compilers', () async {
      var test = await runTest(['test.dart', '-c', 'fake']);
      expect(test.stderr, emitsThrough(contains('Invalid compiler `fake`')));
      await test.shouldExit(64);
    });
  });
}
