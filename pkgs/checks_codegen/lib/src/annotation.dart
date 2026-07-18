// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta_meta.dart';

/// Annotation specifying types to generate Subject extensions with `has`
/// getters for fields.
///
/// Annotate an import or export of the `.checks.dart` library.
@Target({
  // ignore: deprecated_member_use TODO use importDirective
  TargetKind.directive,
  TargetKind.exportDirective,
})
final class CheckExtensions {
  final List<Type> types;
  const CheckExtensions(this.types);
}
