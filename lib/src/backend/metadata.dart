// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.backend.metadata;

/// Metadata for a test or test suite.
///
/// This metadata comes from declarations on the test itself; it doesn't include
/// configuration from the user.
class Metadata {
  /// The expressions indicating which platforms the suite supports.
  final String testOn;

  Metadata(this.testOn);
}
