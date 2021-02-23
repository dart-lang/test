// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.7

// ignore: implementation_imports
import 'package:test_core/src/executable.dart' as executable;
import 'package:test_core/src/runner/hack_register_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'runner/node/platform.dart';
import 'runner/browser/platform.dart';

/// Entrypoint to the test executable.
///
/// [stdin] should be provided as a broadcast stream if this function is
/// intended to be called multiple times in the same process, or if there are
/// other accesses to `stdin` from `dart:io` outside this method.
Future<void> main(List<String> args, {Stream<List<int>> stdin}) async {
  registerPlatformPlugin([Runtime.nodeJS], () => NodePlatform());
  registerPlatformPlugin([
    Runtime.chrome,
    Runtime.phantomJS,
    Runtime.firefox,
    Runtime.safari,
    Runtime.internetExplorer
  ], () => BrowserPlatform.start());

  await executable.main(args, stdin: stdin);
}
