// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'utilities.dart';

class MoveBelowEnclosingTestCall extends ResolvedCorrectionProducer {
  static const _wrapInQuotesKind = FixKind(
      'dart.fix.moveBelowEnclosingTestCall',
      DartFixKindPriority.standard,
      "Move below the enclosing 'test' call");

  MoveBelowEnclosingTestCall({required super.context});

  @override
  CorrectionApplicability get applicability =>
      // This fix may break code by moving references to variables away from the
      // scope in which they are declared.
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _wrapInQuotesKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var methodCall = node;
    if (methodCall is! MethodInvocation) return;
    AstNode? enclosingTestCall = findEnclosingTestCall(methodCall);
    if (enclosingTestCall == null) return;

    if (enclosingTestCall.parent is ExpressionStatement) {
      // Move the 'test' call to below the outer 'test' call _statement_.
      enclosingTestCall = enclosingTestCall.parent!;
    }

    if (methodCall.parent is ExpressionStatement) {
      // Move the whole statement (don't leave the semicolon dangling).
      methodCall = methodCall.parent!;
    }

    await builder.addDartFileEdit(file, (builder) {
      var indent = utils.getLinePrefix(enclosingTestCall!.offset);
      var source = utils.getRangeText(range.node(methodCall));

      // Move the source for `methodCall` wholsale to be just after `enclosingTestCall`.
      builder.addDeletion(range.deletionRange(methodCall));
      builder.addSimpleInsertion(
          enclosingTestCall.end, '$eol$eol$indent$source');
    });
  }
}
