// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cc/cc.dart';
import 'package:config/config.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:task_runner/task_runner.dart';

const packageName = 'native_add';
const assetName =
    'package:$packageName/src/${packageName}_bindings_generated.dart';
const sourcePaths = [
  'src/$packageName.c',
];

void main(List<String> args) async {
  final taskRunner = TaskRunner();
  final config =
      await Config.fromArgs(args: args, environment: Platform.environment);
  final nativeAssetsConfig = NativeAssetsCliConfig.fromConfig(config);
  final outDir = nativeAssetsConfig.outDir;
  final packageRoot = nativeAssetsConfig.packageRoot;
  await Directory.fromUri(outDir).create(recursive: true);
  final packaging = nativeAssetsConfig.packaging.preferredPackaging.first;
  final libUri = outDir.resolve(
      nativeAssetsConfig.target.os.libraryFileName(packageName, packaging));
  final sources = [for (final path in sourcePaths) packageRoot.resolve(path)];

  final task = CBuilder(
    config: config,
    sources: sources,
    dynamicLibrary: packaging == Packaging.dynamic ? libUri : null,
    staticLibrary: packaging == Packaging.static ? libUri : null,
  );
  await task.run(taskRunner: taskRunner);

  final builtInfo = BuiltInfo(
    timestamp: DateTime.now().copyWith(millisecond: 0, microsecond: 0),
    assets: [
      Asset(
        name: assetName,
        packaging: packaging,
        target: nativeAssetsConfig.target,
        path: AssetAbsolutePath(libUri),
      )
    ],
  );
  final builtInfoUri = outDir.resolve('built_info.yaml');
  await File.fromUri(builtInfoUri).writeAsString(builtInfo.toYaml());

  final dependencies = Dependencies([
    ...sources,
    packageRoot.resolve('bin/native.dart'),
  ]);
  final dependenciesUri = outDir.resolve('dependencies.yaml');
  await File.fromUri(dependenciesUri).writeAsString(dependencies.toYaml());
}
