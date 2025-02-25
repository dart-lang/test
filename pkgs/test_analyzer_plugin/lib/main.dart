// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes.dart';
import 'src/rules.dart';

final plugin = TestPackagePlugin();

class TestPackagePlugin extends Plugin {
  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(TestInTestRule());
    registry.registerFixForRule(
        TestInTestRule.code, MoveBelowEnclosingTestCall.new);
  }
}
