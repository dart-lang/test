// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.dartium;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../../util/io.dart';
import '../../utils.dart';
import '../application_exception.dart';
import 'browser.dart';

/// A class for running an instance of Dartium.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Dartium implements Browser {
  /// The underlying process.
  Process _process;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  /// A future that completes when the browser process has started.
  ///
  /// This is used to ensure that [close] works regardless of when it's called.
  Future get _onProcessStarted => _onProcessStartedCompleter.future;
  final _onProcessStartedCompleter = new Completer();

  /// Starts a new instance of Dartium open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Dartium executable. Otherwise
  /// the default executable name for the current OS will be used.
  Dartium(url, {String executable}) {
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
      ], environment: {"DART_FLAGS": "--checked"}).then((process) {
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
            "Dartium failed with exit code $exitCode:\n$error");
      });
    }).then(_onExitCompleter.complete).catchError((error, stackTrace) {
      if (stackTrace == null) stackTrace = new Trace.current();
      _onExitCompleter.completeError(
          new ApplicationException(
              "Failed to start Dartium: ${getErrorMessage(error)}."),
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
    var dartium = _executableInEditor();
    if (dartium != null) return dartium;
    return Platform.isWindows ? "dartium.exe" : "dartium";
  }

  String _executableInEditor() {
    var dir = p.dirname(sdkDir);

    if (Platform.isWindows) {
      if (!new File(p.join(dir, "DartEditor.exe")).existsSync()) return null;

      var dartium = p.join(dir, "chromium\\chrome.exe");
      return new File(dartium).existsSync() ? dartium : null;
    }

    if (Platform.isMacOS) {
      if (!new File(p.join(dir, "DartEditor.app/Contents/MacOS/DartEditor"))
          .existsSync()) {
        return null;
      }

      var dartium = p.join(
          dir, "chromium/Chromium.app/Contents/MacOS/Chromium");
      return new File(dartium).existsSync() ? dartium : null;
    }

    assert(Platform.isLinux);
    if (!new File(p.join(dir, "DartEditor")).existsSync()) return null;

    var dartium = p.join(dir, "chromium", "chrome");
    return new File(dartium).existsSync() ? dartium : null;
  }
}
