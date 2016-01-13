// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;

import '../../util/io.dart';
import '../../utils.dart';
import 'browser.dart';

final _observatoryRegExp = new RegExp(r"^Observatory listening on ([^ ]+)");

/// A class for running an instance of Dartium.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Dartium extends Browser {
  final name = "Dartium";

  final Future<Uri> observatoryUrl;

  factory Dartium(url, {String executable, bool debug: false}) {
    var completer = new Completer.sync();
    return new Dartium._(() async {
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

      if (debug) {
        completer.complete(_getObservatoryUrl(process.stdout));
      } else {
        completer.complete(null);
      }

      process.exitCode
          .then((_) => new Directory(dir).deleteSync(recursive: true));

      return process;
    }, completer.future);
  }

  Dartium._(Future<Process> startBrowser(), this.observatoryUrl)
      : super(startBrowser);

  /// Starts a new instance of Dartium open to the given [url], which may be a
  /// [Uri] or a [String].
  ///
  /// If [executable] is passed, it's used as the Dartium executable. Otherwise
  /// the default executable name for the current OS will be used.

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

  // TODO(nweiz): simplify this when sdk#23923 is fixed.
  /// Returns the Observatory URL for the Dartium executable with the given
  /// [stdout] stream, or `null` if the correct one couldn't be found.
  ///
  /// Dartium prints out three different Observatory URLs when it starts. Only
  /// one of them is connected to the VM instance running the host page, and the
  /// ordering isn't guaranteed, so we need to figure out which one is correct.
  /// We do so by connecting to the VM service via WebSockets and looking for
  /// the Observatory instance that actually contains an isolate, and returning
  /// the corresponding URI.
  static Future<Uri> _getObservatoryUrl(Stream<List<int>> stdout) async {
    var urlQueue = new StreamQueue(lineSplitter.bind(stdout).map((line) {
      var match = _observatoryRegExp.firstMatch(line);
      return match == null ? null : Uri.parse(match[1]);
    }).where((line) => line != null));

    var operations = [
      urlQueue.next,
      urlQueue.next,
      urlQueue.next
    ].map(_checkObservatoryUrl);

    urlQueue.cancel();

    /// Dartium will print three possible observatory URLs. For each one, we
    /// check whether it's actually connected to an isolate, indicating that
    /// it's the observatory for the main page. Once we find the one that is, we
    /// cancel the other requests and return it.
    return inCompletionOrder(operations)
        .firstWhere((url) => url != null, defaultValue: () => null);
  }

  /// If the URL returned by [future] corresponds to the correct Observatory
  /// instance, returns it. Otherwise, returns `null`.
  ///
  /// If the returned operation is canceled before it fires, the WebSocket
  /// connection with the given Observatory will be closed immediately.
  static CancelableOperation<Uri> _checkObservatoryUrl(Future<Uri> future) {
    var webSocket;
    var canceled = false;
    var completer = new CancelableCompleter(onCancel: () {
      canceled = true;
      if (webSocket != null) webSocket.close();
    });

    // We've encountered a format we don't understand. Close the web socket and
    // complete to null.
    giveUp() {
      webSocket.close();
      if (!completer.isCompleted) completer.complete();
    }

    future.then((url) async {
      try {
        webSocket = await WebSocket.connect(
            url.replace(scheme: 'ws', path: '/ws').toString());
        if (canceled) {
          webSocket.close();
          return null;
        }

        webSocket.add(JSON.encode({
          "jsonrpc": "2.0",
          "method": "streamListen",
          "params": {"streamId": "Isolate"},
          "id": "0"
        }));

        webSocket.add(JSON.encode({
          "jsonrpc": "2.0",
          "method": "getVM",
          "params": {},
          "id": "1"
        }));

        webSocket.listen((response) {
          try {
            response = JSON.decode(response);
          } on FormatException catch (_) {
            giveUp();
            return;
          }

          // If there's a "response" key, we're probably talking to the pre-1.0
          // VM service protocol, in which case we should just give up.
          if (response is! Map || response.containsKey("response")) {
            giveUp();
            return;
          }

          if (response["id"] == "0") return;

          if (response["id"] == "1") {
            var result = response["result"];
            if (result is! Map) {
              giveUp();
              return;
            }

            var isolates = result["isolates"];
            if (isolates is! List) {
              giveUp();
              return;
            }

            if (isolates.isNotEmpty) {
              webSocket.close();
              if (!completer.isCompleted) completer.complete(url);
            }
            return;
          }

          // The 1.0 protocol used a raw "event" key, while the 2.0 protocol
          // wraps it in JSON-RPC method params.
          var event;
          if (response.containsKey("event")) {
            event = response["event"];
          } else {
            var params = response["params"];
            if (params is Map) event = params["event"];
          }

          if (event is! Map) {
            giveUp();
            return;
          }

          if (event["kind"] != "IsolateStart") return;
          webSocket.close();
          if (completer.isCompleted) return;

          // TODO(nweiz): include the isolate ID in the URL?
          completer.complete(url);
        });
      } on IOException catch (_) {
        // IO exceptions are probably caused by connecting to an
        // incorrect WebSocket that already closed.
        return null;
      }
    }).catchError((error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    });

    return completer.operation;
  }
}
