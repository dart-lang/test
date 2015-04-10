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
class Firefox implements Browser {
  /// The underlying process.
  Process _process;

  /// The temporary directory used as the browser's user data dir.
  ///
  /// A new data dir is created for each run to ensure that they're
  /// well-isolated.
  String _dir;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  /// A future that completes when the browser process has started.
  ///
  /// This is used to ensure that [close] works regardless of when it's called.
  Future get _onProcessStarted => _onProcessStartedCompleter.future;
  final _onProcessStartedCompleter = new Completer();

  /// Starts a new instance of Firefox open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Firefox executable. Otherwise
  /// the default executable name for the current OS will be used.
  Firefox(url, {String executable}) {
    if (executable == null) executable = _defaultExecutable();

    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    withTempDir((dir) {
      _dir = dir;

      new File(p.join(dir, 'prefs.js')).writeAsStringSync(_preferences);

      return Process.start(executable, [
        "--profile",
        "$_dir",
        url.toString(),
        "--no-remote"
      ]).then((process) {
        _process = process;
        _onProcessStartedCompleter.complete();

        // TODO(nweiz): the browser's standard output is almost always useless
        // noise, but we should allow the user to opt in to seeing it.
        return _process.exitCode;
      });
    }).then((exitCode) {
      if (exitCode != 0) throw "Firefox failed with exit code $exitCode.";
    }).then(_onExitCompleter.complete)
        .catchError(_onExitCompleter.completeError);
  }

  Future close() {
    _onProcessStarted.then((_) => _process.kill());

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.catchError((_) {});
  }

  /// Return the default executable for the current operating system.
  String _defaultExecutable() {
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
