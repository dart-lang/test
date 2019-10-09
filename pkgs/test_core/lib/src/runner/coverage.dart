// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;

import 'live_suite_controller.dart';
import 'runner_suite.dart';

/// Collects coverage and outputs to the [coverage] path.
Future<Null> gatherCoverage(
    String coverage, LiveSuiteController controller) async {
  final RunnerSuite suite = controller.liveSuite.suite;

  if (!suite.platform.runtime.isDartVM) return;

  final String isolateId = Uri.parse(suite.environment.observatoryUrl.fragment)
      .queryParameters['isolateId'];

  final cov = await collect(
      suite.environment.observatoryUrl, false, false, false, Set(),
      isolateIds: {isolateId});

  final outfile = File(p.join('$coverage', '${suite.path}.vm.json'))
    ..createSync(recursive: true);
  final IOSink out = outfile.openWrite();
  out.write(json.encode(cov));
  await out.flush();
  await out.close();
}
