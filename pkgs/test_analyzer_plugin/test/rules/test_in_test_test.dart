// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_analyzer_plugin/src/rules/test_in_test_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../with_test_package.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TestInTestTest);
  });
}

@reflectiveTest
class TestInTestTest extends AnalysisRuleTest with WithTestPackage {
  @override
  void setUp() {
    rule = TestInTestRule();
    super.setUp();
  }

  void test_groupInGroup() async {
    await assertNoDiagnostics(r'''
import 'package:test_core/test_core.dart';
void f() {
  group('one',
    () {
      group('two', () {});
    },
  );
}
''');
  }

  void test_groupInTest() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  test('one',
    () {
      group('two', () {});
    },
  );
}
''',
      [lint(83, 5)],
    );
  }

  void test_groupInSetUp() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  setUp(() {
    group('two', () {});
  });
}
''',
      [lint(71, 5)],
    );
  }

  void test_testInGroup() async {
    await assertNoDiagnostics(r'''
import 'package:test_core/test_core.dart';
void f() {
  group('one',
    () {
      test('two', () {});
    },
  );
}
''');
  }

  void test_testInTest() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  test('one',
    () {
      test('two', () {});
    },
  );
}
''',
      [lint(83, 4)],
    );
  }

  void test_testInSetUp() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  setUp(() {
    test('two', () {});
  });
}
''',
      [lint(71, 4)],
    );
  }

  void test_testInSetUpAll() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  setUpAll(() {
    test('two', () {});
  });
}
''',
      [lint(74, 4)],
    );
  }

  void test_testInTearDown() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  tearDown(() {
    test('two', () {});
  });
}
''',
      [lint(74, 4)],
    );
  }

  void test_testInTearDownAll() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  tearDownAll(() {
    test('two', () {});
  });
}
''',
      [lint(77, 4)],
    );
  }

  void test_setUpInSetUp() async {
    await assertDiagnostics(
      r'''
import 'package:test_core/test_core.dart';
void f() {
  setUp(() {
    setUp(() {});
  });
}
''',
      [lint(71, 5)],
    );
  }

  void test_setUpInGroup() async {
    await assertNoDiagnostics(r'''
import 'package:test_core/test_core.dart';
void f() {
  group('', () {
    setUp(() {});
  });
}
''');
  }
}
