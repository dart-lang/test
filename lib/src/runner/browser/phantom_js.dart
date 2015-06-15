// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.phantom_js;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/exit_codes.dart' as exit_codes;
import '../../util/io.dart';
import '../application_exception.dart';
import 'browser.dart';

/// The PhantomJS script that opens the host page.
final _script = """
var system = require('system');
var page = require('webpage').create();

// PhantomJS versions older than 2.0.0 don't support the latest WebSocket spec.
if (phantom.version.major < 2) phantom.exit(${exit_codes.protocol});

// Pipe browser messages to the process's stdout. This isn't used by default,
// but it can be useful for debugging.
page.onConsoleMessage = function(message) {
  console.log(message);
}

page.open(system.args[1], function(status) {
  if (status !== "success") phantom.exit(1);
});
""";

/// A class for running an instance of PhantomJS.
///
/// Any errors starting or running the process are reported through [onExit].
class PhantomJS extends Browser {
  final name = "PhantomJS";

  PhantomJS(url, {String executable})
      : super(() => _startBrowser(url, executable));

  /// Starts a new instance of PhantomJS open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the PhantomJS executable.
  /// Otherwise the default executable name for the current OS will be used.
  static Future<Process> _startBrowser(url, [String executable]) async {
    if (executable == null) {
      executable = Platform.isWindows ? "phantomjs.exe" : "phantomjs";
    }

    var dir = createTempDir();
    var script = p.join(dir, "script.js");
    new File(script).writeAsStringSync(_script);

    var process = await Process.start(
        executable, [script, url.toString()]);

    // PhantomJS synchronously emits standard output, which means that if we
    // don't drain its stdout stream it can deadlock.
    process.stdout.listen((_) {});

    process.exitCode.then((exitCode) {
      new Directory(dir).deleteSync(recursive: true);

      if (exitCode == exit_codes.protocol) {
        throw new ApplicationException(
            "Only PhantomJS version 2.0.0 or greater is supported");
      }
    });

    return process;
  }
}
