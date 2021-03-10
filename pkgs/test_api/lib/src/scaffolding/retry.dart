// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta_meta.dart';

/// An annotation for marking a test suite to be retried.
///
/// A test with retries enabled will be re-run if it fails for a reason
/// other than [TestFailure].
@Target({TargetKind.library})
class Retry {
  /// The number of times the test will be retried.
  final int count;

  /// Marks a test to be retried.
  const Retry(this.count);
}
