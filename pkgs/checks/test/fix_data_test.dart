// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  test('fix_data applies expected fixes', () async {
    final checksUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'checks/checks.dart'),
    );
    check(checksUri).isNotNull();
    final packageDir = Directory.fromUri(checksUri!.resolve('..'));
    final testFixesDir = Directory.fromUri(checksUri.resolve('../test_fixes'));
    final result = await Process.run(Platform.resolvedExecutable, [
      '--suppress-analytics',
      'fix',
      '--compare-to-golden',
      testFixesDir.path,
    ], workingDirectory: packageDir.path);
    final stdout = result.stdout as String;
    final stderr = result.stderr as String;
    check(
      because: 'stdout:\n$stdout\nstderr:\n$stderr',
      result.exitCode,
    ).equals(0);
    check(
        because: 'at least one fix golden test should run\nstdout:\n$stdout',
        stdout,
      )
      ..contains('Passed: ')
      ..not(.it()..contains('Passed: 0'));
  });
}
