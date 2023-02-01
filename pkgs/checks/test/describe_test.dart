// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('describe', () {
    test('succeeds for empty conditions', () {
      (describe(would())).must.beEmpty();
    });
    test('includes condition clauses', () {
      (describe(would()..equal(1))).must.deeplyEqual(['  equals <1>']);
    });
    test('includes nested clauses', () {
      (describe(would<String>()..haveLength.equal(1))).must.deeplyEqual([
        '  has length that:',
        '    equals <1>',
      ]);
    });
  });
}
