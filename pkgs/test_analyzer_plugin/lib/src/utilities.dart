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

/// Finds an enclosing call to the 'test', 'setUp', 'setUpAll', 'tearDown', or
/// 'tearDownAll' function if there is one.
MethodInvocation? findEnclosingTestOrSetUpOrTearDownCall(
  MethodInvocation node,
) {
  var ancestor = node.parent?.thisOrAncestorOfType<MethodInvocation>();
  while (ancestor != null) {
    var methodName = ancestor.methodName;
    if (methodName.isTest ||
        methodName.name == 'setUp' ||
        methodName.name == 'setUpAll' ||
        methodName.name == 'tearDown' ||
        methodName.name == 'tearDownAll') {
      if (methodName.isFromTestCore) {
        return ancestor;
      }
    }
    ancestor = ancestor.parent?.thisOrAncestorOfType<MethodInvocation>();
  }
  return null;
}

extension SimpleIdentifierExtension on SimpleIdentifier {
  /// Whether this identifier represents the 'test', 'group', 'setUp',
  /// 'setUpAll', 'tearDown', or 'tearDownAll' function from the 'test_core'
  /// package.
  bool get isTestOrGroupOrSetUpOrTearDown {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'test' &&
        element.name != 'group' &&
        element.name != 'setUp' &&
        element.name != 'setUpAll' &&
        element.name != 'tearDown' &&
        element.name != 'tearDownAll') {
      return false;
    }
    return element.library?.uri.path.startsWith('test_core/') ?? false;
  }

  /// Whether this identifier represents the 'test', 'setUp', 'setUpAll',
  /// 'tearDown', or 'tearDownAll' function from the 'test_core' package.
  bool get isTestOrSetUpOrTearDown {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'test' &&
        element.name != 'setUp' &&
        element.name != 'setUpAll' &&
        element.name != 'tearDown' &&
        element.name != 'tearDownAll') {
      return false;
    }
    return isFromTestCore;
  }

  /// Whether this identifier represents the 'test' function from the
  /// 'test_core' package.
  bool get isTest {
    final element = this.element;
    if (element == null) return false;
    return element.name == 'test' && isFromTestCore;
  }

  /// Whether this identifier represents the 'group' function from the
  /// 'test_core' package.
  bool get isGroup {
    final element = this.element;
    if (element == null) return false;
    return element.name == 'group' && isFromTestCore;
  }

  bool get isFromTestCore =>
      element?.library?.uri.path.startsWith('test_core/') ?? false;

  /// Whether this identifier represents the 'expect' function from the
  /// 'matcher' package.
  bool get isExpect {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'expect') return false;
    return element.library?.uri.path.startsWith('matcher/') ?? false;
  }

  /// Whether this identifier represents the 'isFalse' matcher from the
  /// 'matcher' package.
  bool get isIsFalse {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'isFalse') return false;
    return element.library?.uri.path.startsWith('matcher/') ?? false;
  }

  /// Whether this identifier represents the 'isTrue' matcher from the
  /// 'matcher' package.
  bool get isIsTrue {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'isTrue') return false;
    return element.library?.uri.path.startsWith('matcher/') ?? false;
  }

  /// Whether this identifier represents the 'isNotNull' constant from the
  /// 'matcher' package.
  bool get isNotNull {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'isNotNull') return false;
    return element.library?.uri.path.startsWith('matcher/') ?? false;
  }

  /// Whether this identifier represents the 'isNull' constant from the
  /// 'matcher' package.
  bool get isNull {
    final element = this.element;
    if (element == null) return false;
    if (element.name != 'isNull') return false;
    return element.library?.uri.path.startsWith('matcher/') ?? false;
  }
}
