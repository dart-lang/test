// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/dart/error/lint_codes.dart';
import 'package:analyzer/src/lint/linter.dart';

import 'utilities.dart';

class TestInTestRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'test_in_test',
    "Do not declare a 'test' or a 'group' inside a 'test'",
    correctionMessage: "Try moving 'test' or 'group' outside of 'test'",
  );

  TestInTestRule()
      : super(
          name: 'test_in_test',
          description:
              'Tests and groups declared inside of a test are not properly '
              'registered in the test framework.',
        );

  @override
  LintCode get lintCode => code;

  @override
  void registerNodeProcessors(
      NodeLintRegistry registry, LinterContext context) {
    var visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.methodName.isTest && !node.methodName.isGroup) {
      return;
    }
    var enclosingTestCall = findEnclosingTestCall(node);
    if (enclosingTestCall != null) {
      rule.reportLint(node);
    }
  }
}
