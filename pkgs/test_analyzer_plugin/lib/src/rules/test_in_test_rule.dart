// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utilities.dart';

class TestInTestRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'test_in_test',
    "Do not declare a 'test' or a 'group' inside a '{0}'",
    correctionMessage: "Try moving 'test' or 'group' outside of '{0}'",
  );

  TestInTestRule()
    : super(
        name: 'test_in_test',
        description:
            'Tests and groups declared inside of a test are not properly '
            'registered in the test framework.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.methodName.isTestOrGroupOrSetUpOrTearDown) return;

    var enclosingTestOrSetUpOrTearDownCall =
        findEnclosingTestOrSetUpOrTearDownCall(node);
    if (enclosingTestOrSetUpOrTearDownCall != null) {
      rule.reportAtNode(
        node.methodName,
        arguments: [enclosingTestOrSetUpOrTearDownCall.methodName.name],
      );
    }
  }
}
