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

// TODO(srawlins): Several others; use same name or just different codes?
// * `expect(null, isNotNull)` - always false
// * `expect(null, isNull)`    - always true
// * `expect(7, isNull)`       - always false
class NonNullableIsNotNullRule extends MultiAnalysisRule {
  static const LintCode nonNullableIsNotNullCode = LintCode(
    'non_nullable_is_not_null',
    'Do not check whether a non-nullable value isNotNull',
    correctionMessage: 'Try changing the expectation, or removing it',
  );

  static const LintCode nonNullableIsNullCode = LintCode(
    'non_nullable_is_null',
    'Do not check whether a non-nullable value isNull',
    correctionMessage: 'Try changing the expectation, or removing it',
  );

  NonNullableIsNotNullRule()
      : super(
          name: 'non_nullable_is_not_null',
          description: "Non-nullable values will always pass an 'isNotNull' "
              "expectation and never pass an 'isNull' expectation.",
        );

  @override
  List<LintCode> get diagnosticCodes => [nonNullableIsNotNullCode];

  @override
  void registerNodeProcessors(
      RuleVisitorRegistry registry, RuleContext context) {
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
    if (!node.methodName.isExpect) {
      return;
    }

    if (node.argumentList.arguments
        case [var actual, SimpleIdentifier matcher]) {
      var actualType = actual.staticType;
      if (actualType == null) return;
      if (typeSystem.isNonNullable(actualType)) {
        if (matcher.isNotNull) {
          // The actual value will always match this matcher.
          rule.reportAtNode(matcher,
              diagnosticCode:
                  NonNullableIsNotNullRule.nonNullableIsNotNullCode);
        } else if (matcher.isNull) {
          // The actual value will never match this matcher.
          rule.reportAtNode(matcher,
              diagnosticCode: NonNullableIsNotNullRule.nonNullableIsNullCode);
        }
      }
    }
  }
}
