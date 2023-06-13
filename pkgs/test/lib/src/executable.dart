// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
// ignore: implementation_imports
import 'package:test_core/src/executable.dart' as executable;
import 'package:test_core/src/runner/hack_register_platform.dart'; // ignore: implementation_imports

import 'runner/browser/platform.dart';
import 'runner/node/platform.dart';
import 'runner/wasm/platform.dart';

Future<void> main(List<String> args) async {
  registerPlatformPlugin([Runtime.nodeJS], NodePlatform.new);
  registerPlatformPlugin([
    Runtime.chrome,
    Runtime.edge,
    Runtime.firefox,
    Runtime.safari,
    Runtime.internetExplorer
  ], BrowserPlatform.start);
  registerPlatformPlugin([
    Runtime.experimentalChromeWasm,
  ], BrowserWasmPlatform.start);

  await executable.main(args);
}
