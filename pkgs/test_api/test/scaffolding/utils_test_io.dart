// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

void platformTests() {
  test(
      'Suite relative paths should be resolved by using Uri.base + suitePath '
      'on the VM', () {
    final resolved = Uri.base.resolve(suitePath!).resolve('test_data.txt');
    expect(resolved.scheme, 'file');
    expect(resolved.isAbsolute, true);
    expect(resolved.path,
        endsWith('pkgs/test_api/test/scaffolding/test_data.txt'));
    final file = File.fromUri(resolved);
    expect(file.existsSync(), true);
    expect(file.readAsStringSync(), 'hello\n');
  });
}
