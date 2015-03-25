// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.backend.platform_selector;

import 'package:source_span/source_span.dart';

import 'operating_system.dart';
import 'platform_selector/ast.dart';
import 'platform_selector/evaluator.dart';
import 'platform_selector/parser.dart';
import 'platform_selector/visitor.dart';
import 'test_platform.dart';

/// The set of all valid variable names.
final _validVariables =
    new Set<String>.from(["posix", "dart-vm", "browser", "js", "blink"])
        ..addAll(TestPlatform.all.map((platform) => platform.identifier))
        ..addAll(OperatingSystem.all.map((os) => os.name));

/// An expression for selecting certain platforms, including operating systems
/// and browsers.
///
/// The syntax is mostly Dart's expression syntax restricted to boolean
/// operations. See the README for full details.
class PlatformSelector {
  /// The parsed AST.
  final Node _selector;

  /// Parses [selector].
  ///
  /// This will throw a [SourceSpanFormatException] if the selector is
  /// malformed or if it uses an undefined variable.
  PlatformSelector.parse(String selector)
      : _selector = new Parser(selector).parse() {
    _selector.accept(const _VariableValidator());
  }

  /// Returns whether the selector matches the given [platform] and [os].
  ///
  /// [os] defaults to [OperatingSystem.none].
  bool evaluate(TestPlatform platform, {OperatingSystem os}) =>
      _selector.accept(new Evaluator(platform, os: os));
}

/// An AST visitor that ensures that all variables are valid.
///
/// This isn't done when evaluating to ensure that errors are eagerly detected,
/// and it isn't done when parsing to avoid coupling the syntax too tightly to
/// the semantics.
class _VariableValidator extends RecursiveVisitor {
  const _VariableValidator();

  void visitVariable(VariableNode node) {
    if (_validVariables.contains(node.name)) return;
    throw new SourceSpanFormatException("Undefined variable.", node.span);
  }
}
