// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The [PackageConfig] parsed from the current isolates package config file.
final Future<PackageConfig> currentPackageConfig = () async {
  return loadPackageConfigUri(await packageConfigUri);
}();

final Future<Uri> packageConfigUri = () async {
  var uri = await Isolate.packageConfig;
  if (uri == null) {
    throw StateError('Unable to find a package config');
  }
  return uri;
}();

final _originalWorkingDirectory = Directory.current.uri;

/// Returns an `package:` URI for [path] if it is in a package, otherwise
/// returns an absolute file URI.
Future<Uri> absoluteUri(String path) async {
  final uri = p.toUri(path);
  final absoluteUri =
      uri.isAbsolute ? uri : _originalWorkingDirectory.resolveUri(uri);
  try {
    final packageConfig = await currentPackageConfig;
    return packageConfig.toPackageUri(absoluteUri) ?? absoluteUri;
  } on StateError {
    // Workaround for a missing package config.
    return absoluteUri;
  }
}

/// Returns the current package.
final Future<Package> currentPackage = () async {
  return (await currentPackageConfig).packageOf(await packageConfigUri)!;
}();

/// Returns the names of all the packages in the workspace.
///
/// The returned set includes the package's own name (if the package is not a
/// workspace, that will be the only name in the set).
Set<String> workspacePackageNames(Package package) =>
    _allWorkspaceNames(package.root, <String>{});

Set<String> _allWorkspaceNames(Uri packageRoot, Set<String> results) {
  final pubspecUri = packageRoot.resolve('pubspec.yaml');
  final pubspecFile = File(pubspecUri.toFilePath());
  if (pubspecFile.existsSync()) {
    final yaml = pubspecFile.readAsStringSync();
    final pubspec = loadYaml(yaml, sourceUrl: pubspecUri);
    results.add(pubspec['name'] as String);
    for (final package in pubspec['workspace'] as Iterable? ?? const []) {
      _allWorkspaceNames(packageRoot.resolve('$package/'), results);
    }
  }
  return results;
}
