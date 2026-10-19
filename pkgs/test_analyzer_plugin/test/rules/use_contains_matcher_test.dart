// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_analyzer_plugin/src/rules/use_contains_matcher_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UseContainsMatcherTest);
  });
}

@reflectiveTest
class UseContainsMatcherTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = UseContainsMatcherRule();
    super.setUp();

    var matcherPath = '/packages/matcher';
    newFile('$matcherPath/lib/matcher.dart', '''
void expect(dynamic actual, dynamic matcher) {}

const isNotNull = 0;
const isNull = 0;

const isEmpty = 0;
const isFalse = 0;
const isNotEmpty = 0;
const isTrue = 0;

class Matcher {}
Matcher contains(Object? expected) => throw UnimplementedError();
''');
    writeTestPackageConfig(
      PackageConfigFileBuilder()
        ..add(name: 'matcher', rootPath: convertPath(matcherPath)),
    );
  }

  void test_contains_false() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.contains(''), false);
}
''',
      [lint(76, 5, name: 'use_is_not_and_contains_matchers')],
    );
  }

  void test_contains_isFalse() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.contains(''), isFalse);
}
''',
      [lint(76, 7, name: 'use_is_not_and_contains_matchers')],
    );
  }

  void test_contains_isTrue() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.contains(''), isTrue);
}
''',
      [lint(76, 6, name: 'use_contains_matcher')],
    );
  }

  void test_contains_true() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.contains(''), true);
}
''',
      [lint(76, 4, name: 'use_contains_matcher')],
    );
  }

  void test_containsMatcher() async {
    await assertNoDiagnostics(r'''
import 'package:matcher/matcher.dart';
void f() {
  expect('', contains(''));
}
''');
  }

  void test_notContainsParens_false() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(!(''.contains('')), false);
}
''',
      [lint(79, 5, name: 'use_contains_matcher')],
    );
  }

  void test_notContains_isFalse() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f(String s) {
  expect(!s.contains(''), isFalse);
}
''',
      [lint(84, 7, name: 'use_contains_matcher')],
    );
  }

  void test_notContains_isTrue() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f(String s) {
  expect(!s.contains(''), isTrue);
}
''',
      [lint(84, 6, name: 'use_is_not_and_contains_matchers')],
    );
  }

  void test_notContains_true() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f(String s) {
  expect(!s.contains(''), true);
}
''',
      [lint(84, 4, name: 'use_is_not_and_contains_matchers')],
    );
  }
}
