// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.safari;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/io.dart';
import 'browser.dart';

/// A class for running an instance of Safari.
///
/// Any errors starting or running the process are reported through [onExit].
class Safari implements Browser {
  /// The underlying process.
  Process _process;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  /// A future that completes when the browser process has started.
  ///
  /// This is used to ensure that [close] works regardless of when it's called.
  Future get _onProcessStarted => _onProcessStartedCompleter.future;
  final _onProcessStartedCompleter = new Completer();

  /// Starts a new instance of Safari open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Safari executable. Otherwise
  /// the default executable name for the current OS will be used.
  Safari(url, {String executable}) {
    if (executable == null) {
      executable = '/Applications/Safari.app/Contents/MacOS/Safari';
    }

    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    withTempDir((dir) {
      // Safari will only open files (not general URLs) via the command-line
      // API, so we create a dummy file to redirect it to the page we actually
      // want it to load.
      var redirect = p.join(dir, 'redirect.html');
      new File(redirect).writeAsStringSync(
          "<script>location = " + JSON.encode(url.toString()) + "</script>");

      return Process.start(executable, [redirect]).then((process) {
        _process = process;
        _onProcessStartedCompleter.complete();

        // TODO(nweiz): the browser's standard output is almost always useless
        // noise, but we should allow the user to opt in to seeing it.
        return _process.exitCode;
      });
    }).then((exitCode) {
      if (exitCode != 0) throw "Safari failed with exit code $exitCode.";
    }).then(_onExitCompleter.complete)
        .catchError(_onExitCompleter.completeError);
  }

  Future close() {
    _onProcessStarted.then((_) => _process.kill());

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.catchError((_) {});
  }
}
