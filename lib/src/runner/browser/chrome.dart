// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.chrome;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/io.dart';
import 'browser.dart';

// TODO(nweiz): move this into its own package?
/// A class for running an instance of Chrome.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Chrome extends Browser {
  final name = "Chrome";

  /// Starts a new instance of Chrome open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Chrome executable. Otherwise
  /// the default executable name for the current OS will be used.
  Chrome(url, {String executable})
      : super(() => _startBrowser(url, executable));

  static Future<Process> _startBrowser(url, [String executable]) async {
    if (executable == null) executable = _defaultExecutable();

    var dir = createTempDir();
    var process = await Process.start(executable, [
      "--user-data-dir=$dir",
      url.toString(),
      "--disable-extensions",
      "--disable-popup-blocking",
      "--bwsi",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-default-apps",
      "--disable-translate"
    ]);

    process.exitCode
        .then((_) => new Directory(dir).deleteSync(recursive: true));

    return process;
  }

  /// Return the default executable for the current operating system.
  static String _defaultExecutable() {
    if (Platform.isMacOS) {
      return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    }
    if (!Platform.isWindows) return 'google-chrome';

    // Chrome could be installed in several places on Windows. The only way to
    // find it is to check.
    var prefixes = [
      Platform.environment['LOCALAPPDATA'],
      Platform.environment['PROGRAMFILES'],
      Platform.environment['PROGRAMFILES(X86)']
    ];
    var suffix = r'Google\Chrome\Application\chrome.exe';

    for (var prefix in prefixes) {
      if (prefix == null) continue;

      var path = p.join(prefix, suffix);
      if (new File(p.join(prefix, suffix)).existsSync()) return path;
    }

    // Fall back on looking it up on the path. This probably won't work, but at
    // least it will fail with a useful error message.
    return "chrome.exe";
  }
}
