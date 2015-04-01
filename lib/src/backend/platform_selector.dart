// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.platform_selector;

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
/// operations. See [the README][] for full details.
///
/// [the README]: https://github.com/dart-lang/test/#platform-selector-syntax
abstract class PlatformSelector {
  /// A selector that declares that a test can be run on all platforms.
  ///
  /// This isn't representable in the platform selector syntax but it is the
  /// default selector.
  static const all = const _AllPlatforms();

  /// Parses [selector].
  ///
  /// This will throw a [SourceSpanFormatException] if the selector is
  /// malformed or if it uses an undefined variable.
  factory PlatformSelector.parse(String selector) =>
      new _PlatformSelector.parse(selector);

  /// Returns whether the selector matches the given [platform] and [os].
  ///
  /// [os] defaults to [OperatingSystem.none].
  bool evaluate(TestPlatform platform, {OperatingSystem os});

  /// Returns a new [PlatformSelector] that matches only platforms matched by
  /// both [this] and [other].
  PlatformSelector intersect(PlatformSelector other);
}

/// The concrete implementation of a [PlatformSelector] parsed from a string.
///
/// This is separate from [PlatformSelector] so that [_AllPlatforms] can
/// implement [PlatformSelector] without having to implement private members.
class _PlatformSelector implements PlatformSelector{
  /// The parsed AST.
  final Node _selector;

  _PlatformSelector.parse(String selector)
      : _selector = new Parser(selector).parse() {
    _selector.accept(const _VariableValidator());
  }

  _PlatformSelector(this._selector);

  bool evaluate(TestPlatform platform, {OperatingSystem os}) =>
      _selector.accept(new Evaluator(platform, os: os));

  PlatformSelector intersect(PlatformSelector other) {
    if (other == PlatformSelector.all) return this;
    return new _PlatformSelector(new AndNode(
        _selector, (other as _PlatformSelector)._selector));
  }

  String toString() => _selector.toString();
}

/// A selector that matches all platforms.
class _AllPlatforms implements PlatformSelector {
  const _AllPlatforms();

  bool evaluate(TestPlatform platform, {OperatingSystem os}) => true;

  PlatformSelector intersect(PlatformSelector other) => other;

  String toString() => "*";
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
