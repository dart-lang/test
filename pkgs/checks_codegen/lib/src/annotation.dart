// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Annotation specifying types to generate Subject extensions with `has`
/// getters for fields.
///
/// Annotate an import to the `.checks.dart` library.
class CheckExtensions {
  final List<Type> types;
  const CheckExtensions(this.types);
}
