// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/context.dart';

extension NumChecks on Check<num> {
  void operator >(num other) {
    context.expect(() => ['is greater than ${literal(other)}'], (actual) {
      if (actual > other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['Is not greater than ${literal(other)}']);
    });
  }

  void operator <(num other) {
    context.expect(() => ['is less than ${literal(other)}'], (actual) {
      if (actual < other) return null;
      return Rejection(
          actual: literal(actual),
          which: ['Is not less than ${literal(other)}']);
    });
  }
}
