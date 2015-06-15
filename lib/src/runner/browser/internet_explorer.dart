// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.internet_explorer;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'browser.dart';

/// A class for running an instance of Internet Explorer.
///
/// Any errors starting or running the process are reported through [onExit].
class InternetExplorer extends Browser {
  final name = "Internet Explorer";

  InternetExplorer(url, {String executable})
      : super(() => _startBrowser(url, executable));

  /// Starts a new instance of Internet Explorer open to the given [url], which
  /// may be a [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Internet Explorer executable.
  /// Otherwise the default executable name for the current OS will be used.
  static Future<Process> _startBrowser(url, [String executable]) {
    if (executable == null) executable = _defaultExecutable();
    return Process.start(executable, ['-extoff', url.toString()]);
  }

  /// Return the default executable for the current operating system.
  static String _defaultExecutable() {
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
