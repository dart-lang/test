// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The version number of the test runner, or `null` if it couldn't be loaded.
///
/// This is a semantic version, optionally followed by a space and additional
/// data about its source.
final String? testVersion = _readWorkspaceRef() ?? _readPubspecLock();

String? _readWorkspaceRef() {
  try {
    final workspaceRefPath = p.join('.dart_tool', 'pub', 'workspace_ref.json');
    final workspaceRefFile = File(workspaceRefPath);
    if (!workspaceRefFile.existsSync()) return null;
    final ref = jsonDecode(workspaceRefFile.readAsStringSync());
    if (ref is! Map) return null;
    final relativeRoot = ref['workspaceRoot'];
    if (relativeRoot is! String) return null;
    final packageGraphPath = p.normalize(
      p.join(
        '.dart_tool',
        'pub',
        relativeRoot,
        '.dart_tool',
        'package_graph.json',
      ),
    );
    final packageGraphFile = File(packageGraphPath);
    final packageGraph = jsonDecode(packageGraphFile.readAsStringSync());
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

  switch (source) {
    case 'hosted':
      var version = package['version'];
      return (version is String) ? version : null;

    case 'git':
      var version = package['version'];
      if (version is! String) return null;
      var description = package['description'];
      if (description is! Map) return null;
      var ref = description['resolved-ref'];
      if (ref is! String) return null;

      return '$version (${ref.substring(0, 7)})';

    case 'path':
      var version = package['version'];
      if (version is! String) return null;
      var description = package['description'];
      if (description is! Map) return null;
      var path = description['path'];
      if (path is! String) return null;

      return '$version (from $path)';

    default:
      return null;
  }
}
