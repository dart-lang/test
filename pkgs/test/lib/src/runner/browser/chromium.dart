// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports

import '../executable_settings.dart';
import 'default_settings.dart';

enum ChromiumBasedBrowser {
  chrome(Runtime.chrome),
  microsoftEdge(Runtime.edge);

  final Runtime runtime;

  const ChromiumBasedBrowser(this.runtime);

  Future<Process> spawn(
    Uri url,
    Configuration configuration, {
    ExecutableSettings? settings,
    List<String> additionalArgs = const [],
  }) async {
    settings ??= defaultSettings[runtime];

    var dir = createTempDir();
    var args = [
      '--user-data-dir=$dir',
      url.toString(),
      '--enable-logging=stderr',
      '--v=0',
      '--disable-extensions',
      '--disable-popup-blocking',
      '--bwsi',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-default-apps',
      '--disable-translate',
      '--disable-dev-shm-usage',
      if (settings!.headless && !configuration.pauseAfterLoad) ...[
        '--headless',
        '--disable-gpu',
      ],
      if (!configuration.debug)
        // We don't actually connect to the remote debugger, but Chrome will
        // close as soon as the page is loaded if we don't turn it on.
        '--remote-debugging-port=0',
      ...settings.arguments,
      ...additionalArgs,
    ];

    var process = await Process.start(settings.executable, args);

    unawaited(process.exitCode.then((_) => Directory(dir).deleteWithRetry()));

    return process;
  }
}
