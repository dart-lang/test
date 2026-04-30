// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The semantic version number of the test runner, or `null` if it couldn't be
/// found.
final String? testVersion = _readWorkspaceRef() ?? _readPubspecLock();

String? _readWorkspaceRef() {
  try {
    final pubDirectory = p.join('.dart_tool', 'pub');
    final workspaceRefFile = File(p.join(pubDirectory, 'workspace_ref.json'));
    if (!workspaceRefFile.existsSync()) return null;
    final workspaceRef = jsonDecode(workspaceRefFile.readAsStringSync());
    if (workspaceRef is! Map) return null;
    final relativeRoot = workspaceRef['workspaceRoot'];
    if (relativeRoot is! String) return null;
    final packageGraphPath = p.normalize(
      p.join(pubDirectory, relativeRoot, '.dart_tool', 'package_graph.json'),
    );
    final packageGraph = jsonDecode(File(packageGraphPath).readAsStringSync());
    if (packageGraph is! Map) return null;
    final packages = packageGraph['packages'];
    if (packages is! List) return null;
    final testPackage = packages.firstWhereOrNull(
      (p) => p is Map && p['name'] == 'test',
    );
    if (testPackage == null) return null;
    return (testPackage as Map)['version'] as String;
  } on FormatException {
    return null;
  } on IOException {
    return null;
  }
}

String? _readPubspecLock() {
  dynamic lockfile;
  try {
    lockfile = loadYaml(File('pubspec.lock').readAsStringSync());
  } on FormatException {
    return null;
  } on IOException {
    return null;
  }

  if (lockfile is! Map) return null;
  var packages = lockfile['packages'];
  if (packages is! Map) return null;
  var package = packages['test'];
  if (package is! Map) return null;
  var source = package['source'];
  if (source is! String) return null;
  var version = package['version'];
  return (version is String) ? version : null;
}
