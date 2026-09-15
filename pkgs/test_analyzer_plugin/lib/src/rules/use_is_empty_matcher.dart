// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../utilities.dart';

class UseIsEmptyMatcherRule extends MultiAnalysisRule {
  static const LintCode useIsEmptyMatcherCode = LintCode(
    'use_is_empty_matcher',
    "Use the 'isEmpty' matcher.",
  );

  static const LintCode useIsNotEmptyMatcherCode = LintCode(
    'use_is_not_empty_matcher',
    "Use the 'isNotEmpty' matcher.",
  );

  UseIsEmptyMatcherRule()
    : super(
        name: 'use_is_empty_matcher',
        description: "Use the built-in 'isEmpty' and 'isNotEmpty' matchers.",
      );

  @override
  List<LintCode> get diagnosticCodes => [
    useIsEmptyMatcherCode,
    useIsNotEmptyMatcherCode,
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

    bool actualIsIsEmpty;
    if (actual is PrefixedIdentifier) {
      if (actual.identifier.name == 'isEmpty') {
        actualIsIsEmpty = true;
      } else if (actual.identifier.name == 'isNotEmpty') {
        actualIsIsEmpty = false;
      } else {
        return;
      }
    } else if (actual is PropertyAccess) {
      if (actual.propertyName.name == 'isEmpty') {
        actualIsIsEmpty = true;
      } else if (actual.propertyName.name == 'isNotEmpty') {
        actualIsIsEmpty = false;
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

    if (actualIsIsEmpty == matcherValue) {
      // Either `expect(a.isEmpty, isTrue|true)` or
      // `expect(a.isNotEmpty, isFalse|false)`.
      rule.reportAtNode(
        matcher,
        diagnosticCode: UseIsEmptyMatcherRule.useIsEmptyMatcherCode,
      );
    } else {
      // Either `expect(a.isEmpty, isFalse|false)` or
      // `expect(a.isNotEmpty, isTrue|true)`.
      rule.reportAtNode(
        matcher,
        diagnosticCode: UseIsEmptyMatcherRule.useIsNotEmptyMatcherCode,
      );
    }
  }
}
