// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.content_shell;

import 'dart:async';
import 'dart:io';

import '../../utils.dart';
import '../application_exception.dart';
import 'browser.dart';

/// A class for running an instance of the Dartium content shell.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class ContentShell extends Browser {
  final name = "Content Shell";

  ContentShell(url, {String executable})
      : super(() => _startBrowser(url, executable));

  /// Starts a new instance of content shell open to the given [url], which may
  /// be a [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the content shell executable.
  /// Otherwise the default executable name for the current OS will be used.
  static Future<Process> _startBrowser(url, [String executable]) async {
    if (executable == null) executable = _defaultExecutable();

    var process = await Process.start(
        executable, ["--dump-render-tree", url.toString()],
        environment: {"DART_FLAGS": "--checked"});

    lineSplitter.bind(process.stderr).listen((line) {
      if (line != "[dartToStderr]: Dartium build has expired") return;

      // TODO(nweiz): link to dartlang.org once it has download links for
      // content shell
      // (https://github.com/dart-lang/www.dartlang.org/issues/1164).
      throw new ApplicationException(
          "You're using an expired content_shell. Upgrade to the latest "
              "version:\n"
          "http://gsdview.appspot.com/dart-archive/channels/stable/release/"
              "latest/dartium/");
    });

    return process;
  }

  /// Return the default executable for the current operating system.
  static String _defaultExecutable() =>
      Platform.isWindows ? "content_shell.exe" : "content_shell";
}
