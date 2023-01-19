// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';

extension FailureCheck on Check<CheckFailure?> {
  void isARejection({List<String>? which, List<String>? actual}) {
    isNotNull()
        .has((f) => f.rejection, 'rejection')
        ._hasActualWhich(actual: actual, which: which);
  }
}

extension RejectionCheck on Check<Rejection?> {
  void isARejection({List<String>? which, List<String>? actual}) {
    isNotNull()._hasActualWhich(actual: actual, which: which);
  }
}

extension _RejectionCheck on Check<Rejection> {
  void _hasActualWhich({List<String>? which, List<String>? actual}) {
    if (actual != null) {
      has((r) => r.actual.toList(), 'actual').deepEquals(actual);
    }
    final whichCheck = has((r) => r.which?.toList(), 'which');
    if (which == null) {
      whichCheck.isNull();
    } else {
      whichCheck.isNotNull().deepEquals(which);
    }
  }
}
