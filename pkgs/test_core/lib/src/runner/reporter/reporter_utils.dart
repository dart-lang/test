// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports

import '../load_suite.dart';

/// Returns a description of [liveTest].
///
/// This differs from the test's own description in that it may also include
/// the suite's name and platform details.
String formatTestDescription(
  LiveTest liveTest, {
  required bool printPath,
  required bool printPlatform,
  String bold = '',
  String gray = '',
  String noColor = '',
}) {
  var name = liveTest.test.name;

  if (printPath &&
      liveTest.suite is! LoadSuite &&
      liveTest.suite.path != null) {
    name = '${liveTest.suite.path}: $name';
  }

  if (printPlatform) {
    name =
        '[${liveTest.suite.platform.runtime.name}, '
        '${liveTest.suite.platform.compiler.name}] $name';
  }

  if (liveTest.suite is LoadSuite) name = '$bold$gray$name$noColor';

  return name;
}
