// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.frontend.tags;

/// An annotation for applying a set of tags for a test suite.
class Tags {
  /// Tags applied to a test suite.
  final tags;

  /// Applies a set of tags to a test suite.
  ///
  /// [tags] is either an [Iterable] specifying one or more tags, or a [String]
  /// specifying one tag.
  const Tags([this.tags]);
}
