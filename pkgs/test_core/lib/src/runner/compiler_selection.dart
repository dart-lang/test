// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'package:test_api/backend.dart';

/// A compiler with which the user has chosen to run tests.
class CompilerSelection {
  /// The chosen compiler to use.
  final Compiler compiler;

  /// The location in the configuration file of this compiler string, or `null`
  /// if it was defined outside a configuration file (for example, on the
  /// command line).
  final SourceSpan? span;

  /// The platform selector for which platforms this compiler should apply to,
  /// if specified. Defaults to all platforms where the compiler is supported.
  final PlatformSelector? platformSelector;

  CompilerSelection(String compiler,
      {required this.platformSelector, required this.span})
      : compiler = Compiler.builtIn.firstWhere((c) => c.identifier == compiler);

  factory CompilerSelection.parse(String option, {SourceSpan? parentSpan}) {
    var parts = option.split(':');
    switch (parts.length) {
      case 1:
        _checkValidCompiler(option, parentSpan);
        return CompilerSelection(option,
            platformSelector: null, span: parentSpan);
      case 2:
        var compiler = parts[1];
        _checkValidCompiler(compiler, parentSpan);
        return CompilerSelection(compiler,
            platformSelector: PlatformSelector.parse(parts[0]),
            span: parentSpan);
      default:
        throw ArgumentError.value(
            option,
            '--compiler',
            'Must be of the format [<boolean-selector>:]<compiler>, but got '
                'more than one `:`.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CompilerSelection && other.compiler == compiler;

  @override
  int get hashCode => compiler.hashCode;
}

void _checkValidCompiler(String compiler, SourceSpan? span) {
  if (Compiler.builtIn.any((c) => c.identifier == compiler)) return;
  throw SourceSpanFormatException(
      'Invalid compiler `$compiler`, must be one of ${Compiler.builtIn.map((c) => c.identifier).join(', ')}',
      span);
}
