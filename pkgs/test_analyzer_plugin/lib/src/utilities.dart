// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';

/// Finds an enclosing call to the 'test' function, if there is one.
MethodInvocation? findEnclosingTestCall(MethodInvocation node) {
  var ancestor = node.parent?.thisOrAncestorOfType<MethodInvocation>();
  while (ancestor != null) {
    if (ancestor.methodName.isTest) {
      return ancestor;
    }
    ancestor = ancestor.parent?.thisOrAncestorOfType<MethodInvocation>();
  }
  return null;
}

extension SimpleIdentifierExtension on SimpleIdentifier {
  /// Whether this identifier represents the 'test' function from the
  /// 'test_core' package.
  bool get isTest {
    final element = this.element;
    if (element == null) return false;
    if (element.name3 != 'test') return false;
    return element.library2?.uri.path.startsWith('test_core/') ?? false;
  }

  /// Whether this identifier represents the 'group' function from the
  /// 'test_core' package.
  bool get isGroup {
    final element = this.element;
    if (element == null) return false;
    if (element.name3 != 'group') return false;
    return element.library2?.uri.path.startsWith('test_core/') ?? false;
  }
}
