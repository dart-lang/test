// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.chrome;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../../util/io.dart';
import '../../utils.dart';
import '../application_exception.dart';
import 'browser.dart';

// TODO(nweiz): move this into its own package?
// TODO(nweiz): support other browsers.
/// A class for running an instance of Chrome.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Chrome implements Browser {
  /// The underlying process.
  Process _process;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  /// A future that completes when the browser process has started.
  ///
  /// This is used to ensure that [close] works regardless of when it's called.
  Future get _onProcessStarted => _onProcessStartedCompleter.future;
  final _onProcessStartedCompleter = new Completer();

  /// Starts a new instance of Chrome open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Chrome executable. Otherwise
  /// the default executable name for the current OS will be used.
  Chrome(url, {String executable}) {
    if (executable == null) executable = _defaultExecutable();

    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    withTempDir((dir) {
      return Process.start(executable, [
        "--user-data-dir=$dir",
        url.toString(),
        "--disable-extensions",
        "--disable-popup-blocking",
        "--bwsi",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-default-apps",
        "--disable-translate"
      ]).then((process) {
        _process = process;
        _onProcessStartedCompleter.complete();

        // TODO(nweiz): the browser's standard output is almost always useless
        // noise, but we should allow the user to opt in to seeing it.
        return _process.exitCode;
      });
    }).then((exitCode) {
      if (exitCode == 0) return null;

      return UTF8.decodeStream(_process.stderr).then((error) {
        throw new ApplicationException(
            "Chrome failed with exit code $exitCode:\n$error");
      });
    }).then(_onExitCompleter.complete).catchError((error, stackTrace) {
      if (stackTrace == null) stackTrace = new Trace.current();
      _onExitCompleter.completeError(
          new ApplicationException(
              "Failed to start Chrome: ${getErrorMessage(error)}."),
          stackTrace);
    });
  }

  Future close() {
    _onProcessStarted.then((_) => _process.kill());

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.catchError((_) {});
  }

  /// Return the default executable for the current operating system.
  String _defaultExecutable() {
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
