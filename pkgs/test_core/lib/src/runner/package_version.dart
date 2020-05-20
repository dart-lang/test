// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// A comment which forces the language version to be that of the current
/// packages default.
///
/// If the cwd is not a package, this returns an empty string which ends up
/// defaulting to the current sdk version.
final Future<String> rootPackageLanguageVersionComment = () async {
  var packageConfig = await loadPackageConfigUri(await Isolate.packageConfig);
  Package? rootPackage =
      packageConfig.packageOf(Uri.file(p.absolute('foo.dart')));
  if (rootPackage == null) return '';
  return '// @dart=${rootPackage.languageVersion}';
}();
