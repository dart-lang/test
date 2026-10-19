// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../utilities.dart';

class UseContainsMatcherRule extends MultiAnalysisRule {
  static const LintCode useIsContainsCode = LintCode(
    'use_contains_matcher',
    "Use the 'contains' matcher.",
  );

  static const LintCode useIsNotAndContainsMatchersCode = LintCode(
    'use_is_not_and_contains_matchers',
    "Use the 'isNot' and 'contains' matchers.",
  );

  UseContainsMatcherRule()
    : super(
        name: 'use_is_empty_matcher',
        description: "Use the built-in 'contains' matcher.",
      );

  @override
  List<LintCode> get diagnosticCodes => [
    useIsContainsCode,
    useIsNotAndContainsMatchersCode,
  ];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this, context.typeSystem);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final MultiAnalysisRule rule;

  final TypeSystem typeSystem;

  _Visitor(this.rule, this.typeSystem);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.methodName.isExpect) return;

    var arguments = node.argumentList.arguments;
    if (arguments.isEmpty || arguments.length > 2) return;
    var [actual, matcher] = arguments;

    bool actualIsContains;
    if (actual is MethodInvocation && actual.methodName.name == 'contains') {
      actualIsContains = true;
    } else if (actual is PrefixExpression &&
        actual.operator.type == TokenType.BANG) {
      var operand = actual.operand.unParenthesized;
      if (operand is MethodInvocation &&
          operand.methodName.name == 'contains') {
        actualIsContains = false;
      } else {
        return;
      }
    } else {
      return;
    }

    bool matcherValue;
    if (matcher is BooleanLiteral) {
      matcherValue = matcher.value;
    } else if (matcher is SimpleIdentifier && matcher.isIsFalse) {
      matcherValue = false;
    } else if (matcher is SimpleIdentifier && matcher.isIsTrue) {
      matcherValue = true;
    } else {
      return;
    }

    if (actualIsContains == matcherValue) {
      // Either `expect(a.contains(...), isTrue|true)` or
      // `expect(!a.contains(...), isFalse|false)`.
      rule.reportAtNode(
        matcher,
        diagnosticCode: UseContainsMatcherRule.useIsContainsCode,
      );
    } else {
      // Either `expect(a.contains(...), isFalse|false)` or
      // `expect(!a.contains(...), isTrue|true)`.
      rule.reportAtNode(
        matcher,
        diagnosticCode: UseContainsMatcherRule.useIsNotAndContainsMatchersCode,
      );
    }
  }
}
