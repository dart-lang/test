// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

const _testPackageRootExtension = 'ext.test.testPackageRoot';

/// Registers a service extension [_testPackageRootExtension] that returns the
/// package root of the test being executed, which should be passed in as the
/// [packageRootFileUri] parameter.
///
/// The value of [packageRootFileUri] should be equivalent to the current
/// working directory where the test runner was started. This is because the
/// test runner (started by `dart test` or `flutter test`) must be started from
/// a package root that contains the `.dart_tool/package_config.json` file, and
/// all test targets must be contained within that package root.
///
/// [packageRootFileUri] is expected to be a file uri (i.e. starting
/// with 'file://').
///
/// The value of [packageRootFileUri] is passed in as a parameter here instead
/// of computing the current working directory because we need to avoid a
/// dependency on dart:io from pacakge:test_api.
///
/// Example usage:
///
/// registerTestPackageRootServiceExtension(
///   Uri.file(Directory.current.absolute.path).toString(),
/// );
void registerTestPackageRootServiceExtension(String packageRootFileUri) {
  if (!packageRootFileUri.startsWith('file://')) {
    throw ArgumentError.value(
      packageRootFileUri,
      'rootPathFileUri',
      'must be a file:// URI String',
    );
  }

  registerExtension(_testPackageRootExtension, (method, parameters) async {
    return ServiceExtensionResponse.result(
      json.encode({'value': packageRootFileUri}),
    );
  });
}
