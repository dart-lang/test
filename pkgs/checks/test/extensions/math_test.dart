// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('NumChecks', () {
    test('greater-than', () {
      checkThat(42) > 7;
      checkThat(softCheck<int>(42, (p0) => p0 > 50))
          .isARejection(actual: '<42>', which: ['Is not greater than <50>']);
    });
    test('less-than', () {
      checkThat(42) < 50;
      checkThat(softCheck<int>(42, (p0) => p0 < 7))
          .isARejection(actual: '<42>', which: ['Is not less than <7>']);
    });
  });
}
