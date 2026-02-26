// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports

/// The maximum number of individual failing tests to list in the summary.
const maxFailureSummaryCount = 5;

/// Writes a summary of failed and incomplete tests to [sink].
///
/// [failed] are tests that completed with a failure or error. [active] are
/// tests that did not complete before the run ended. Active tests are
/// annotated with `(did not complete)`.
///
/// The list is sorted by `(suite.path, test.name)` for deterministic output.
/// At most [maxFailureSummaryCount] tests are listed individually; if there
/// are more, a "... and N more" line is appended.
void writeFailureSummary(
  StringSink sink, {
  required Iterable<LiveTest> failed,
  required Iterable<LiveTest> active,
  required String red,
  required String noColor,
}) {
  final entries = <_SummaryEntry>[
    for (final test in failed)
      _SummaryEntry(test.suite.path, test.test.name, didNotComplete: false),
    for (final test in active)
      _SummaryEntry(test.suite.path, test.test.name, didNotComplete: true),
  ];

  if (entries.isEmpty) return;

  entries.sort();

  sink.writeln('');
  sink.writeln('${red}Failing tests:$noColor');

  final displayCount =
      entries.length > maxFailureSummaryCount
          ? maxFailureSummaryCount
          : entries.length;

  for (var i = 0; i < displayCount; i++) {
    final entry = entries[i];
    final suffix = entry.didNotComplete ? ' (did not complete)' : '';
    if (entry.path != null) {
      sink.writeln('  ${entry.path}: ${entry.name}$suffix');
    } else {
      sink.writeln('  ${entry.name}$suffix');
    }
  }

  final remaining = entries.length - displayCount;
  if (remaining > 0) {
    sink.writeln('  ... and $remaining more');
  }
}

class _SummaryEntry implements Comparable<_SummaryEntry> {
  final String? path;
  final String name;
  final bool didNotComplete;

  _SummaryEntry(this.path, this.name, {required this.didNotComplete});

  @override
  int compareTo(_SummaryEntry other) {
    final pathCmp = (path ?? '').compareTo(other.path ?? '');
    if (pathCmp != 0) return pathCmp;
    return name.compareTo(other.name);
  }
}
