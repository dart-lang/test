// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_core/src/util/prefix.dart';

void main() {
  test('testLibraryImportPrefix value is "test"', () {
    expect(
      testLibraryImportPrefix,
      'test',
      reason:
          'testLibraryImportPrefix must be equal to the String "test". Some '
          'tools depend on logic that searches for a prefix named "test" to '
          'find the Dart library being tested.',
    );
  });
}
