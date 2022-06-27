// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';

extension TestIterableCheck on Check<Iterable<String>?> {
  // TODO: remove this once we have a deepEquals or equivalent
  void toStringEquals(List<String>? other) {
    final otherToString = other.toString();
    context.expect(() => ['toString equals'], (actual) {
      final actualToString = actual.toString();
      return actual.toString() == otherToString
          ? null
          : Rejection(actual: actualToString);
    });
  }
}

extension RejectionCheck on Check<Rejection?> {
  void isARejection({List<String>? which, required String actual}) {
    this.isNotNull()
      ..has((p0) => p0.actual, 'actual').equals(actual)
      ..has((p0) => p0.which, 'which').toStringEquals(which);
  }
}
