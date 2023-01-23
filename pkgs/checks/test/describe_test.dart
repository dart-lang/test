// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('describe', () {
    test('succeeds for empty conditions', () {
      checkThat(describe(it())).isEmpty();
    });
    test('includes condition clauses', () {
      checkThat(describe(it()..equals(1))).deepEquals(['  equals <1>']);
    });
    test('includes nested clauses', () {
      checkThat(describe(it<String>()..length.equals(1))).deepEquals([
        '  has length that:',
        '    equals <1>',
      ]);
    });
  });
}
