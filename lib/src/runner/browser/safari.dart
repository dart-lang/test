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
class Safari extends Browser {
  final name = "Safari";

  Safari(url, {String executable})
      : super(() => _startBrowser(url, executable));

  /// Starts a new instance of Safari open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the content shell executable.
  /// Otherwise the default executable name for the current OS will be used.
  static Future<Process> _startBrowser(url, [String executable]) async {
    if (executable == null) {
      executable = '/Applications/Safari.app/Contents/MacOS/Safari';
    }

    var dir = createTempDir();

    // Safari will only open files (not general URLs) via the command-line
    // API, so we create a dummy file to redirect it to the page we actually
    // want it to load.
    var redirect = p.join(dir, 'redirect.html');
    new File(redirect).writeAsStringSync(
        "<script>location = " + JSON.encode(url.toString()) + "</script>");

    var process = await Process.start(executable, [redirect]);

    process.exitCode
        .then((_) => new Directory(dir).deleteSync(recursive: true));

    return process;
  }
}
