// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

/// A compiler with which the user has chosen to run tests.
class CompilerSelection {
  /// The name of the compiler.
  final String name;

  /// The location in the configuration file of this compiler string, or `null`
  /// if it was defined outside a configuration file (for example, on the
  /// command line).
  final SourceSpan? span;

  CompilerSelection(this.name, [this.span]);

  @override
  bool operator ==(other) => other is CompilerSelection && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
