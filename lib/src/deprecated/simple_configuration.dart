// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.deprecated.simple_configuration;

import 'test_case.dart';
import 'configuration.dart';

/// This is a stub class used to preserve compatibility with unittest 0.11.*.
///
/// It will be removed before the next version is released.
@deprecated
class SimpleConfiguration extends Configuration {
  bool throwOnTestFailures = true;
  SimpleConfiguration() : super.blank();

  String formatResult(TestCase testCase) => "";
}
