// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.dartium;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/io.dart';
import 'browser.dart';

/// A class for running an instance of Dartium.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Dartium extends Browser {
  final name = "Dartium";

  Dartium(url, {String executable})
      : super(() => _startBrowser(url, executable));

  /// Starts a new instance of Dartium open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Dartium executable. Otherwise
  /// the default executable name for the current OS will be used.
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
    ], environment: {"DART_FLAGS": "--checked"});

    process.exitCode
        .then((_) => new Directory(dir).deleteSync(recursive: true));

    return process;
  }

  /// Return the default executable for the current operating system.
  static String _defaultExecutable() {
    var dartium = _executableInEditor();
    if (dartium != null) return dartium;
    return Platform.isWindows ? "dartium.exe" : "dartium";
  }

  static String _executableInEditor() {
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
