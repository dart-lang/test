// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.firefox;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/io.dart';
import 'browser.dart';

final _preferences = '''
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("dom.disable_open_during_load", false);
user_pref("dom.max_script_run_time", 0);
''';

/// A class for running an instance of Firefox.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Firefox extends Browser {
  final name = "Firefox";

  Firefox(url, {String executable})
      : super(() => _startBrowser(url, executable));

  /// Starts a new instance of Firefox open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Firefox executable.
  /// Otherwise the default executable name for the current OS will be used.
  static Future<Process> _startBrowser(url, [String executable]) async {
    if (executable == null) executable = _defaultExecutable();

    var dir = createTempDir();
    new File(p.join(dir, 'prefs.js')).writeAsStringSync(_preferences);

    var process = await Process.start(executable, [
      "--profile", "$dir",
      url.toString(),
      "--no-remote"
    ], environment: {
      "MOZ_CRASHREPORTER_DISABLE": "1"
    });

    process.exitCode
        .then((_) => new Directory(dir).deleteSync(recursive: true));

    return process;
  }

  /// Return the default executable for the current operating system.
  static String _defaultExecutable() {
    if (Platform.isMacOS) {
      return '/Applications/Firefox.app/Contents/MacOS/firefox-bin';
    }
    if (!Platform.isWindows) return 'firefox';

    // Firefox could be installed in several places on Windows. The only way to
    // find it is to check.
    var prefixes = [
      Platform.environment['PROGRAMFILES'],
      Platform.environment['PROGRAMFILES(X86)']
    ];
    var suffix = r'Mozilla Firefox\firefox.exe';

    for (var prefix in prefixes) {
      if (prefix == null) continue;

      var path = p.join(prefix, suffix);
      if (new File(p.join(prefix, suffix)).existsSync()) return path;
    }

    // Fall back on looking it up on the path. This probably won't work, but at
    // least it will fail with a useful error message.
    return "firefox.exe";
  }
}
