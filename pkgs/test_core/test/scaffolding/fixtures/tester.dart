// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart' as test_package;

typedef TestFunction = dynamic Function();

class Test {
  final String name;
  final TestFunction function;

  Test(this.name, this.function);
}

void main() {
  var tests = [
    Test('a', () {}),
    Test('b', () => throw test_package.TestFailure('b')),
    Test('c', () {}),
    Test('d', () => throw test_package.TestFailure('d')),
    Test('e', () {}),
  ];

  for (var test in tests) {
    test_package.test(test.name, () async {
      try {
        await test.function();
      } finally {}
    });
  }
}
