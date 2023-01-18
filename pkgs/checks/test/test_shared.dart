// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';

extension TestIterableCheck on Check<Iterable<String>?> {
  // TODO: remove this once we have a deepEquals or equivalent
  void toStringEquals(List<String>? other) {
    final otherToString = other.toString();
    context.expect(
      () => prefixFirst('toString equals ', literal(otherToString)),
      (actual) {
        final actualToString = actual.toString();
        return actualToString == otherToString
            ? null
            : Rejection(
                actual: literal(actualToString),
                which: ['does not have a matching toString'],
              );
      },
    );
  }
}

extension RejectionCheck on Check<CheckFailure?> {
  void isARejection({List<String>? which, List<String>? actual}) {
    final rejection = this.isNotNull().has((f) => f.rejection, 'rejection');
    if (actual != null) {
      rejection
          .has((p0) => p0.actual.toList(), 'actual')
          .toStringEquals(actual);
    }
    rejection.has((p0) => p0.which?.toList(), 'which').toStringEquals(which);
  }
}
