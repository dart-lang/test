// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'live_suite_controller.dart';

Future<Coverage> writeCoverage(
  String? coveragePath,
  LiveSuiteController controller,
) =>
    throw UnsupportedError(
      'Coverage is only supported through the test runner.',
    );

Future<void> writeCoverageLcov(String coverageLcov, Coverage allCoverageData) =>
    throw UnsupportedError(
      'Coverage is only supported through the test runner.',
    );

typedef Coverage = Map<String, void>;

extension Merge on Coverage {
  void merge(Coverage other) =>
      throw UnsupportedError(
        'Coverage is only supported through the test runner.',
      );
}
