// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports

/// The maximum number of individual failing tests to list in the summary.
const maxFailureSummaryCount = 5;

/// Writes a summary of [failedTests] to [sink].
///
/// At most [maxFailureSummaryCount] tests are listed individually; if there
/// are more, a "... and N more" line is appended.
void writeFailureSummary(
  StringSink sink,
  Iterable<LiveTest> failedTests, {
  required String red,
  required String noColor,
}) {
  final failed = failedTests.toList();
  if (failed.isEmpty) return;

  sink.writeln('');
  sink.writeln('${red}Failing tests:$noColor');

  final displayCount =
      failed.length > maxFailureSummaryCount
          ? maxFailureSummaryCount
          : failed.length;

  for (var i = 0; i < displayCount; i++) {
    final liveTest = failed[i];
    final path = liveTest.suite.path;
    final name = liveTest.test.name;
    if (path != null) {
      sink.writeln('  $path: $name');
    } else {
      sink.writeln('  $name');
    }
  }

  final remaining = failed.length - displayCount;
  if (remaining > 0) {
    sink.writeln('  ... and $remaining more');
  }
}
