// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:coverage/coverage.dart';

import 'live_suite_controller.dart';

Future<Map<String, HitMap>> writeCoverage(
        String? coveragePath, LiveSuiteController controller) =>
    throw UnsupportedError(
        'Coverage is only supported through the test runner.');

Future<void> writeCoverageLcov(
        String coverageLcov, Map<String, HitMap> allCoverageData) =>
    throw UnsupportedError(
        'Coverage is only supported through the test runner.');
