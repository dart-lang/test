// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../util/io.dart';
import '../../utils.dart';
import 'browser.dart';

// TODO(nweiz): move this into its own package?
/// A class for running an instance of Chrome.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Chrome extends Browser {
  final name = "Chrome";

  final Future<Uri> remoteDebuggerUrl;

  /// Starts a new instance of Chrome open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Chrome executable. Otherwise
  /// the default executable name for the current OS will be used.
  factory Chrome(url, {String executable, bool debug: false}) {
    var remoteDebuggerCompleter = new Completer<Uri>.sync();
    return new Chrome._(() async {
      if (executable == null) executable = _defaultExecutable();

      var tryPort = ([int port]) async {
        var dir = createTempDir();
        var args = [
          "--user-data-dir=$dir", url.toString(), "--disable-extensions",
          "--disable-popup-blocking", "--bwsi", "--no-first-run",
          "--no-default-browser-check", "--disable-default-apps",
          "--disable-translate",
        ];

        if (port != null) {
          args.add("--remote-debugging-port=$port");
          // These flags cause Chrome to print a consistent line of output after
          // its internal call to `bind()` has succeeded or failed. We wait for
          // that output to determine whether the port we chose worked.
          args.add("--enable-logging=stderr");
          args.add("--vmodule=startup_browser_creator_impl=1");
        }

        var process = await Process.start(executable, args);

        if (port != null) {
          var stderr = new StreamIterator(lineSplitter.bind(process.stderr));

          // Before we can consider Chrome to have started successfully, we have
          // to make sure the remote debugging port worked. Any errors from this
          // will always come before the "startup_browser_creater_impl" message.
          while (await stderr.moveNext() &&
              !stderr.current.contains("startup_browser_creator_impl")) {
            if (stderr.current.contains("bind() returned an error")) {
              // If we failed to bind to the port, return null to tell
              // getUnusedPort to try another one.
              stderr.cancel();
              process.kill();
              return null;
            }
          }
        }

        if (port != null) {
          remoteDebuggerCompleter.complete(
              getRemoteDebuggerUrl(Uri.parse("http://localhost:$port")));
        } else {
          remoteDebuggerCompleter.complete(null);
        }

        process.exitCode
            .then((_) => new Directory(dir).deleteSync(recursive: true));

        return process;
      };

      if (!debug) return tryPort();
      return getUnusedPort/*<Future<Process>>*/(tryPort);
    }, remoteDebuggerCompleter.future);
  }

  Chrome._(Future<Process> startBrowser(), this.remoteDebuggerUrl)
      : super(startBrowser);

  /// Return the default executable for the current operating system.
  static String _defaultExecutable() {
    if (Platform.isMacOS) {
      return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    }
    if (!Platform.isWindows) return 'google-chrome';

    // Chrome could be installed in several places on Windows. The only way to
    // find it is to check.
    var prefixes = [
      Platform.environment['LOCALAPPDATA'],
      Platform.environment['PROGRAMFILES'],
      Platform.environment['PROGRAMFILES(X86)']
    ];
    var suffix = r'Google\Chrome\Application\chrome.exe';

    for (var prefix in prefixes) {
      if (prefix == null) continue;

      var path = p.join(prefix, suffix);
      if (new File(p.join(prefix, suffix)).existsSync()) return path;
    }

    // Fall back on looking it up on the path. This probably won't work, but at
    // least it will fail with a useful error message.
    return "chrome.exe";
  }
}
