// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.content_shell;

import 'dart:async';
import 'dart:io';

import 'browser.dart';

/// A class for running an instance of the Dartium content shell.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class ContentShell implements Browser {
  /// The underlying process.
  Process _process;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  /// A future that completes when the browser process has started.
  ///
  /// This is used to ensure that [close] works regardless of when it's called.
  Future get _onProcessStarted => _onProcessStartedCompleter.future;
  final _onProcessStartedCompleter = new Completer();

  /// Starts a new instance of content shell open to the given [url], which may
  /// be a [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the content shell executable.
  /// Otherwise the default executable name for the current OS will be used.
  ContentShell(url, {String executable}) {
    if (executable == null) executable = _defaultExecutable();

    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    Process.start(executable, ["--dump-render-tree", url.toString()],
        environment: {"DART_FLAGS": "--checked"}).then((process) {
      _process = process;
      _onProcessStartedCompleter.complete();
      return _process.exitCode;
    }).then((exitCode) {
      if (exitCode != 0) throw "Content shell failed with exit code $exitCode.";
    }).then(_onExitCompleter.complete)
        .catchError(_onExitCompleter.completeError);
  }

  Future close() {
    _onProcessStarted.then((_) => _process.kill());

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.catchError((_) {});
  }

  /// Return the default executable for the current operating system.
  String _defaultExecutable() =>
      Platform.isWindows ? "content_shell.exe" : "content_shell";
}
