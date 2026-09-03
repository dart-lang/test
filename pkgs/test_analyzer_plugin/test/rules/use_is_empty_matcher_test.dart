// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_analyzer_plugin/src/rules/use_is_empty_matcher.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UseIsEmptyMatcherTest);
  });
}

@reflectiveTest
class UseIsEmptyMatcherTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = UseIsEmptyMatcherRule();
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
''');
    writeTestPackageConfig(
      PackageConfigFileBuilder()
        ..add(name: 'matcher', rootPath: convertPath(matcherPath)),
    );
  }

  void test_isEmpty_false() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isEmpty, false);
}
''',
      [lint(71, 5, name: 'use_is_not_empty_matcher')],
    );
  }

  void test_isEmpty_isFalse() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isEmpty, isFalse);
}
''',
      [lint(71, 7, name: 'use_is_not_empty_matcher')],
    );
  }

  void test_isEmpty_isTrue() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isEmpty, isTrue);
}
''',
      [
        lint(71, 6, messageContainsAll: ['isEmpty']),
      ],
    );
  }

  void test_isEmpty_true() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isEmpty, true);
}
''',
      [
        lint(71, 4, messageContainsAll: ['isEmpty']),
      ],
    );
  }

  void test_isEmptyMatcher() async {
    await assertNoDiagnostics(r'''
import 'package:matcher/matcher.dart';
void f() {
  expect('', isEmpty);
}
''');
  }

  void test_isNotEmpty_false() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isNotEmpty, false);
}
''',
      [
        lint(74, 5, messageContainsAll: ['isEmpty']),
      ],
    );
  }

  void test_isNotEmpty_isFalse() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isNotEmpty, isFalse);
}
''',
      [
        lint(74, 7, messageContainsAll: ['isEmpty']),
      ],
    );
  }

  void test_isNotEmpty_isTrue() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isNotEmpty, isTrue);
}
''',
      [lint(74, 6, name: 'use_is_not_empty_matcher')],
    );
  }

  void test_isNotEmpty_true() async {
    await assertDiagnostics(
      r'''
import 'package:matcher/matcher.dart';
void f() {
  expect(''.isNotEmpty, true);
}
''',
      [lint(74, 4, name: 'use_is_not_empty_matcher')],
    );
  }
}
