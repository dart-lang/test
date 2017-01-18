// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A declarative description of a filesystem entry.
///
/// This may be extended outside this package.
abstract class Descriptor {
  /// This entry's basename.
  final String name;

  Descriptor(this.name);

  /// Creates this entry within the [parent] directory, which defaults to
  /// [sandbox].
  Future create([String parent]);

  /// Validates that the physical file system under [parent] (which defaults to
  /// [sandbox]) contains an entry that matches this descriptor.
  Future validate([String parent]);

  /// Returns a human-friendly tree-style description of this descriptor.
  String describe();
}
