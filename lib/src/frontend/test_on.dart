// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.frontend.test_on;

/// An annotation indicating which platforms a test or test suite supports.
///
/// For the full syntax of [expression], see [the README][readme].
///
/// [readme]: https://github.com/dart-lang/unittest/#readme
class TestOn {
  /// The expression specifying the platform.
  final String expression;

  const TestOn(this.expression);
}
