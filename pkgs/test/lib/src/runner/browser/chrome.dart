// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.7

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pedantic/pedantic.dart';
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import '../executable_settings.dart';
import 'browser.dart';
import 'default_settings.dart';

/// A class for running an instance of Chrome.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Chrome extends Browser {
  @override
  final name = 'Chrome';

  @override
  final Future<Uri> remoteDebuggerUrl;

  final Future<WipConnection> _tabConnection;
  final Map<String, String> _idToUrl;

  /// Starts a new instance of Chrome open to the given [url], which may be a
  /// [Uri] or a [String].
  factory Chrome(Uri url, Configuration configuration,
      {ExecutableSettings settings}) {
    settings ??= defaultSettings[Runtime.chrome];
    var remoteDebuggerCompleter = Completer<Uri>.sync();
    var connectionCompleter = Completer<WipConnection>();
    var idToUrl = <String, String>{};
    return Chrome._(() async {
      var tryPort = ([int port]) async {
        var dir = createTempDir();
        var args = [
          '--user-data-dir=$dir',
          url.toString(),
          '--disable-extensions',
          '--disable-popup-blocking',
          '--bwsi',
          '--no-first-run',
          '--no-default-browser-check',
          '--disable-default-apps',
          '--disable-translate',
          '--disable-dev-shm-usage',
          if (settings.headless && !configuration.pauseAfterLoad) ...[
            '--headless',
            '--disable-gpu',
          ],
          if (!configuration.debug)
            // We don't actually connect to the remote debugger, but Chrome will
            // close as soon as the page is loaded if we don't turn it on.
            '--remote-debugging-port=0',
          ...settings.arguments,
          if (port != null)
            // Chrome doesn't provide any way of ensuring that this port was
            // successfully bound. It produces an error if the binding fails,
            // but without a reliable and fast way to tell if it succeeded that
            // doesn't provide us much. It's very unlikely that this port will
            // fail, though.
            '--remote-debugging-port=$port',
        ];

        var process = await Process.start(settings.executable, args);

        if (port != null) {
          remoteDebuggerCompleter.complete(
              getRemoteDebuggerUrl(Uri.parse('http://localhost:$port')));

          connectionCompleter.complete(_connect(process, port, idToUrl, url));
        } else {
          remoteDebuggerCompleter.complete(null);
        }

        unawaited(process.exitCode
            .then((_) => Directory(dir).deleteSync(recursive: true)));

        return process;
      };

      if (!configuration.debug) return tryPort();
      return getUnusedPort<Process>(tryPort);
    }, remoteDebuggerCompleter.future, connectionCompleter.future, idToUrl);
  }

  /// Returns a Dart based hit-map containing coverage report, suitable for use
  /// with `package:coverage`.
  Future<Map<String, dynamic>> gatherCoverage() async {
    var tabConnection = await _tabConnection;
    var response = await tabConnection.debugger.connection
        .sendCommand('Profiler.takePreciseCoverage', {});
    var result = response.result['result'];
    var coverage = await parseChromeCoverage(
      (result as List).cast(),
      _sourceProvider,
      _sourceMapProvider,
      _sourceUriProvider,
    );
    return coverage;
  }

  Chrome._(Future<Process> Function() startBrowser, this.remoteDebuggerUrl,
      this._tabConnection, this._idToUrl)
      : super(startBrowser);

  Future<Uri> _sourceUriProvider(String sourceUrl, String scriptId) async {
    var script = _idToUrl[scriptId];
    if (script == null) return null;
    var sourceUri = Uri.parse(sourceUrl);
    if (sourceUri.scheme == 'file') return sourceUri;
    // If the provided sourceUrl is relative, determine the package path.
    var uri = Uri.parse(script);
    var path = p.join(
        p.joinAll(uri.pathSegments.sublist(1, uri.pathSegments.length - 1)),
        sourceUrl);
    return path.contains('/packages/')
        ? Uri(scheme: 'package', path: path.split('/packages/').last)
        : null;
  }

  Future<String> _sourceMapProvider(String scriptId) async {
    var script = _idToUrl[scriptId];
    if (script == null) return null;
    var mapResponse = await http.get('$script.map');
    if (mapResponse.statusCode != HttpStatus.ok) return null;
    return mapResponse.body;
  }

  Future<String> _sourceProvider(String scriptId) async {
    var script = _idToUrl[scriptId];
    if (script == null) return null;
    var scriptResponse = await http.get(script);
    if (scriptResponse.statusCode != HttpStatus.ok) return null;
    return scriptResponse.body;
  }
}

Future<WipConnection> _connect(
    Process process, int port, Map<String, String> idToUrl, Uri url) async {
  // Wait for Chrome to be in a ready state.
  await process.stderr
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .firstWhere((line) => line.startsWith('DevTools listening'));

  var chromeConnection = ChromeConnection('localhost', port);
  ChromeTab tab;
  var attempt = 0;
  while (tab == null) {
    attempt++;
    var tabs = await chromeConnection.getTabs();
    tab =
        tabs.firstWhere((tab) => tab.url == url.toString(), orElse: () => null);
    if (tab == null) {
      await Future.delayed(Duration(milliseconds: 100));
      if (attempt > 5) {
        throw StateError('Could not connect to test tab with url: $url');
      }
    }
  }
  var tabConnection = await tab.connect();

  // Enable debugging.
  await tabConnection.debugger.enable();

  // Coverage reports are in terms of scriptIds so keep note of URLs.
  tabConnection.debugger.onScriptParsed.listen((data) {
    var script = data.script;
    if (script.url.isNotEmpty) idToUrl[script.scriptId] = script.url;
  });

  // Enable coverage collection.
  await tabConnection.debugger.connection.sendCommand('Profiler.enable', {});
  await tabConnection.debugger.connection.sendCommand(
      'Profiler.startPreciseCoverage', {'detailed': true, 'callCount': false});

  return tabConnection;
}
