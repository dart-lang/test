// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes.dart';
import 'src/rules/non_nullable_is_not_null_rule.dart';
import 'src/rules/test_in_test_rule.dart';

final plugin = TestPackagePlugin();

class TestPackagePlugin extends Plugin {
  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(TestInTestRule());
    registry.registerFixForRule(
        TestInTestRule.code, MoveBelowEnclosingTestCall.new);

    registry.registerWarningRule(NonNullableIsNotNullRule());
    // Should we register a fix for this rule? The only automatic fix I can
    // think of would be to delete the entire statement:
    // `expect(a, isNotNull);` or `expect(a, isNull);`.

    // TODO(srawlins): More rules to catch:
    // * `expect(7, contains(6))` - should only use `hasLength` with `Iterable`
    //   or `String`.
    // * `expect(7, hasLength(3))` - should only use `hasLength` with `Iterable`
    //   or `String`.
    // * `expect([].isEmpty, isFalse)` - should use `isEmpty` matcher.
    // * `expect([].isNotEmpty, isTrue)` - should use `isNotEmpty` matcher.
    // * `expect([].contains(7), isFalse)` - should use `contains` matcher.
  }
}
