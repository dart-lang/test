// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:test_core/src/runner/vm/test_compiler.dart';

void main() {
  group('VM test templates', () {
    test('include package config URI variable', () async {
      // This variable is read through the VM service and should not be removed.
      final template = testBootstrapContents(
        testUri: Uri.file('foo.dart'),
        languageVersionComment: '// version comment',
        packageConfigUri: Uri.file('package_config.json'),
        testType: VmTestType.isolate,
      );
      final lines = LineSplitter.split(template).map((line) => line.trim());
      expect(lines,
          contains("const packageConfigLocation = 'package_config.json';"));
    });
  });
}
