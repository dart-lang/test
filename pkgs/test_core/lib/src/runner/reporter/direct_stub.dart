// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../util/print_sink.dart';
import '../engine.dart';
import '../reporter.dart';
import 'failures_only.dart';

Reporter createDirectReporter(Engine engine) => FailuresOnlyReporter.watch(
  engine,
  PrintSink(),
  color: false,
  printPath: false,
  printPlatform: false,
);
