// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../../util/io.dart';
import '../../util/print_sink.dart';
import '../configuration.dart';
import '../configuration/reporters.dart';
import '../engine.dart';
import '../reporter.dart';
import 'compact.dart';
import 'failures_only.dart';

Reporter createDirectReporter(Engine engine) {
  if (Platform.environment['DART_TEST_REPORTER'] case final envReporter) {
    if (allReporters[envReporter]?.factory case final factory?) {
      return factory(Configuration.empty, engine, PrintSink());
    }
    stderr.writeln('Unknown reporter "$envReporter" in DART_TEST_REPORTER.');
  }

  return canUseSpecialChars
      ? CompactReporter.watch(
          engine,
          PrintSink(),
          color: true,
          printPath: false,
          printPlatform: false,
        )
      : FailuresOnlyReporter.watch(
          engine,
          PrintSink(),
          color: false,
          printPath: false,
          printPlatform: false,
        );
}
