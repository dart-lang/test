// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;

import '../util/package_config.dart';
import 'live_suite_controller.dart';

/// Collects coverage and outputs to the [coveragePath] path.
Future<Coverage> writeCoverage(
  String? coveragePath,
  LiveSuiteController controller,
) async {
  final suite = controller.liveSuite.suite;
  final coverage = await controller.liveSuite.suite.gatherCoverage();
  if (coveragePath != null) {
    final outfile = File(
      p.join(
        coveragePath,
        '${suite.path}.${suite.platform.runtime.name.toLowerCase()}.json',
      ),
    )..createSync(recursive: true);
    final out = outfile.openWrite();
    out.write(json.encode(coverage));
    await out.flush();
    await out.close();
  }
  final hitMapJson = coverage['coverage'] as List<Map<String, dynamic>>?;
  if (hitMapJson == null) return const {};
  return HitMap.parseJson(hitMapJson);
}

Future<void> writeCoverageLcov(
  String coverageLcov,
  Coverage allCoverageData,
) async {
  final resolver = await Resolver.create(
    packagePath: (await currentPackage).root.toFilePath(),
  );
  final filteredCoverageData = allCoverageData.filterIgnored(
    ignoredLinesInFilesCache: {},
    resolver: resolver,
  );
  final lcovData = filteredCoverageData.formatLcov(resolver);
  final outfile = File(coverageLcov)..createSync(recursive: true);
  final out = outfile.openWrite();
  out.write(lcovData);
  await out.flush();
  await out.close();
}

typedef Coverage = Map<String, HitMap>;

extension Merge on Coverage {
  void merge(Coverage other) => FileHitMaps(this).merge(other);
}
