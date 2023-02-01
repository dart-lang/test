// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('sample test', () {
    final someValue = 5;
    someValue.must.equal(5);

    final someList = [1, 2, 3, 4, 5];
    someList.must.deeplyEqual([1, 2, 3, 4, 5]);

    final someString = 'abcdefghijklmnopqrstuvwxyz';

    someString.must
      ..startWith('a')
      ..endWith('z')
      ..contain('lmno');
  });
}
