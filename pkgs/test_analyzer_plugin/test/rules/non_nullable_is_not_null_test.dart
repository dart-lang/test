// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_analyzer_plugin/src/rules/non_nullable_is_not_null_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NonNullableIsNotNullTest);
  });
}

@reflectiveTest
class NonNullableIsNotNullTest extends AnalysisRuleTest {
  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NonNullableIsNotNullRule());

    super.setUp();

    var matcherPath = '/packages/matcher';
    newFile('$matcherPath/lib/matcher.dart', '''
void expect(dynamic actual, dynamic matcher) {}

const isNotNull = 0;
const isNull = 0;
''');
    writeTestPackageConfig(
      PackageConfigFileBuilder()
        ..add(name: 'matcher', rootPath: convertPath(matcherPath)),
    );
  }

  @override
  String get analysisRule => 'non_nullable_is_not_null';

  void test_nullableValue_isNotNullMatcher() async {
    await assertNoDiagnostics(r'''
import 'package:matcher/matcher.dart';
void f(String? p) {
  expect(p, isNotNull);
}
''');
  }

  void test_nonNullableValue_isNotNullMatcher() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(123, isNotNull);
}
''',
      [lint(64, 9)],
    );
  }

  void test_nullableValue_isNullMatcher() async {
    await assertNoDiagnostics(r'''
import 'package:matcher/matcher.dart';
void f(String? p) {
  expect(p, isNull);
}
''');
  }

  void test_nonNullableValue_isNullMatcher() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(123, isNull);
}
''',
      [lint(64, 6, name: 'non_nullable_is_null')],
    );
  }
}
