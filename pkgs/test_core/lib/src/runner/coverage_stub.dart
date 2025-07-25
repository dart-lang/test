// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'live_suite_controller.dart';

Future<void> writeCoverage(
  String coveragePath,
  LiveSuiteController controller,
) =>
    throw UnsupportedError(
      'Coverage is only supported through the test runner.',
    );
