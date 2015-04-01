// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.platform_selector.evaluator;

import '../operating_system.dart';
import '../test_platform.dart';
import 'ast.dart';
import 'visitor.dart';

/// A visitor for evaluating platform selectors against a specific
/// [TestPlatform] and [OperatingSystem].
class Evaluator implements Visitor<bool> {
  /// The platform to test against.
  final TestPlatform _platform;

  /// The operating system to test against.
  final OperatingSystem _os;

  Evaluator(this._platform, {OperatingSystem os})
      : _os = os == null ? OperatingSystem.none : os;

  bool visitVariable(VariableNode node) {
    if (node.name == _platform.identifier) return true;
    if (node.name == _os.name) return true;

    switch (node.name) {
      case "dart-vm": return _platform.isDartVm;
      case "browser": return _platform.isBrowser;
      case "js": return _platform.isJS;
      case "blink": return _platform.isBlink;
      case "posix": return _os.isPosix;
      default: return false;
    }
  }

  bool visitNot(NotNode node) => !node.child.accept(this);

  bool visitOr(OrNode node) =>
      node.left.accept(this) || node.right.accept(this);

  bool visitAnd(AndNode node) =>
      node.left.accept(this) && node.right.accept(this);

  bool visitConditional(ConditionalNode node) => node.condition.accept(this)
      ? node.whenTrue.accept(this)
      : node.whenFalse.accept(this);
}
