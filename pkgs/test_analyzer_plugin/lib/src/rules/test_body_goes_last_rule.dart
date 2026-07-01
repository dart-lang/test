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

class TestBodyGoesLastRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'test_body_goes_last',
    "The body of a '{0}' should go after the other arguments",
    correctionMessage:
        "Try moving the body argument below the other '{0}' arguments",
  );

  TestBodyGoesLastRule()
    : super(
        name: 'test_body_goes_last',
        description:
            'The body of a test or group should go after the other arguments',
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
    if (!node.methodName.isTest && !node.methodName.isGroup) return;

    final arguments = node.argumentList.arguments;

    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument.correspondingParameter?.name == 'body') {
        if (i == arguments.length - 1) return;
        final errorNode = argument is FunctionExpression
            ? argument.parameters
            : argument;
        rule.reportAtNode(errorNode, arguments: [node.methodName.name]);
        // Do not keep iterating through the arguments.
        return;
      }
    }
  }
}
