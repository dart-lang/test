// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.chrome;

import 'dart:async';
import 'dart:io';

import '../../util/io.dart';

// TODO(nweiz): move this into its own package?
// TODO(nweiz): support other browsers.
/// A class for running an instance of Chrome.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Chrome {
  /// The underlying process.
  Process _process;

  /// The temporary directory used as the browser's user data dir.
  ///
  /// A new data dir is created for each run to ensure that they're
  /// well-isolated.
  String _dir;

  /// A future that completes when the browser exits.
  ///
  /// If there's a problem starting or running the browser, this will complete
  /// with an error.
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
  /// `"google-chrome"` will be looked up on the system PATH.
  Chrome(url, {String executable}) {
    if (executable == null) executable = "google-chrome";

    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    withTempDir((dir) {
      _dir = dir;
      return Process.start(executable, [
        "--user-data-dir=$_dir",
        url.toString(),
        "--disable-extensions",
        "--disable-popup-blocking",
        "--bwsi",
        "--no-first-run"
      ]).then((process) {
        _process = process;
        _onProcessStartedCompleter.complete();

        // TODO(nweiz): the browser's standard output is almost always useless
        // noise, but we should allow the user to opt in to seeing it.
        return _process.exitCode;
      });
    }).then((exitCode) {
      if (exitCode != 0) throw "Chrome failed with exit code $exitCode.";
    }).then(_onExitCompleter.complete)
        .catchError(_onExitCompleter.completeError);
  }

  /// Kills the browser process.
  ///
  /// Returns the same [Future] as [onExit], except that it won't emit
  /// exceptions.
  Future close() {
    _onProcessStarted.then((_) => _process.kill());

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.catchError((_) {});
  }
}
