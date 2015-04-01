// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.deprecated.configuration;

import 'test_case.dart';

/// This is a stub class used to preserve compatibility with unittest 0.11.*.
///
/// It will be removed before the next version is released.
@deprecated
class Configuration {
  Configuration();
  Configuration.blank();

  final autoStart = true;
  Duration timeout = const Duration(minutes: 2);
  void onInit() {}
  void onStart() {}
  void onTestStart(TestCase testCase) {}
  void onTestResult(TestCase testCase) {}
  void onTestResultChanged(TestCase testCase) {}
  void onLogMessage(TestCase testCase, String message) {}
  void onDone(bool success) {}
  void onSummary(int passed, int failed, int errors, List<TestCase> results,
      String uncaughtError) {}
}
