// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_analyzer_plugin/src/rules/test_body_goes_last_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../with_test_package.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TestBodyGoesLastTest);
  });
}

@reflectiveTest
class TestBodyGoesLastTest extends AnalysisRuleTest with WithTestPackage {
  @override
  void setUp() {
    rule = TestBodyGoesLastRule();
    super.setUp();
  }

  void test_groupBeforeSkip() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  group('description',
    () {
      // Test case.
    },
    skip: true,
  );
}
''',
      [lint(81, 2)],
    );
  }

  void test_groupLast() async {
    await assertNoDiagnostics(r'''
import 'package:test_core/test_core.dart';
void f() {
  group('description',
    skip: true,
    () {
      // Test case.
    },
  );
}
''');
  }

  void test_testBeforeSkip() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  test('description',
    () {
      // Test case.
    },
    skip: true,
  );
}
''',
      [lint(80, 2)],
    );
  }

  void test_testLast() async {
    await assertNoDiagnostics(r'''
import 'package:test_core/test_core.dart';
void f() {
  test('description',
    skip: true,
    () {
      // Test case.
    },
  );
}
''');
  }
}
