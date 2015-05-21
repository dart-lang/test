// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.internet_explorer;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../../utils.dart';
import '../application_exception.dart';
import 'browser.dart';

/// A class for running an instance of Internet Explorer.
///
/// Any errors starting or running the process are reported through [onExit].
class InternetExplorer implements Browser {
  /// The underlying process.
  Process _process;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  /// A future that completes when the browser process has started.
  ///
  /// This is used to ensure that [close] works regardless of when it's called.
  Future get _onProcessStarted => _onProcessStartedCompleter.future;
  final _onProcessStartedCompleter = new Completer();

  /// Starts a new instance of Internet Explorer open to the given [url], which
  /// may be a [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Internet Explorer executable.
  /// Otherwise the default executable name will be used.
  InternetExplorer(url, {String executable}) {
    if (executable == null) executable = _defaultExecutable();

    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    invoke(() async {
      try {
        var process = await Process.start(
            executable, ['-extoff', url.toString()]);

        _process = process;
        _onProcessStartedCompleter.complete();

        // TODO(nweiz): the browser's standard output is almost always useless
        // noise, but we should allow the user to opt in to seeing it.
        var exitCode = await _process.exitCode;
        if (exitCode != 0) {
          var error = await UTF8.decodeStream(_process.stderr);
          throw new ApplicationException(
              "Internet Explorer failed with exit code $exitCode:\n$error");
        }

        _onExitCompleter.complete();
      } catch (error, stackTrace) {
        if (stackTrace == null) stackTrace = new Trace.current();
        _onExitCompleter.completeError(
            new ApplicationException(
                "Failed to start Internet Explorer: "
                    "${getErrorMessage(error)}."),
            stackTrace);
      }
    });
  }

  Future close() {
    _onProcessStarted.then((_) => _process.kill());

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.catchError((_) {});
  }

  /// Return the default executable for the current operating system.
  String _defaultExecutable() {
    // Internet Explorer could be installed in several places on Windows. The
    // only way to find it is to check.
    var prefixes = [
      Platform.environment['PROGRAMW6432'],
      Platform.environment['PROGRAMFILES'],
      Platform.environment['PROGRAMFILES(X86)']
    ];
    var suffix = r'Internet Explorer\iexplore.exe';

    for (var prefix in prefixes) {
      if (prefix == null) continue;

      var path = p.join(prefix, suffix);
      if (new File(p.join(prefix, suffix)).existsSync()) return path;
    }

    // Fall back on looking it up on the path. This probably won't work, but at
    // least it will fail with a useful error message.
    return "iexplore.exe";
  }
}
