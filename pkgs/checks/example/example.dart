// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('sample test', () {
    final someValue = 5;
    check(someValue).equals(5);

    final someList = [1, 2, 3, 4, 5];
    check(someList).deepEquals([1, 2, 3, 4, 5]);

    final someString = 'abcdefghijklmnopqrstuvwxyz';

    check(
      because: 'it should contain the beginning, middle and end',
      someString,
    )
      ..startsWith('a')
      ..endsWith('z')
      ..contains('lmno');
  });
}
