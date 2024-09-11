// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'utils_test_browser.dart' if (dart.library.io) 'utils_test_io.dart';

void main() {
  test('suitePath is available', () {
    expect(suitePath, 'test/scaffolding/utils_test.dart');
  });

  /// Tests specific to the platform we are running on.
  platformTests();
}
