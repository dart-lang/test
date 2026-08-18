// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_api/scaffolding.dart';

void main() {
  test('TestFailure is exported from package:test_api/scaffolding.dart', () {
    final failure = TestFailure('custom failure');
    if (failure.message != 'custom failure') {
      throw Exception('Unexpected message: ${failure.message}');
    }
  });
}
