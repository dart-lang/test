// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;
import 'package:test_api/backend.dart';
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import '../executable_settings.dart';
import 'browser.dart';
import 'chromium.dart';
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
  Future<Uri?> get remoteDebuggerUrl async => (await _connection)?.$2;

  late final Future<(WipConnection, Uri)?> _connection = _connect();

  final _idToUrl = <String, String>{};
  final Future<int?> _debugPort;
  final Uri _url;

  /// Starts a new instance of Chrome open to the given [url], which may be a
  /// [Uri] or a [String].
  factory Chrome(
    Uri url,
    Configuration configuration, {
    ExecutableSettings? settings,
  }) {
    settings ??= defaultSettings[Runtime.chrome]!;
    var debugPortCompleter = Completer<int?>();
    return Chrome._(
      () async {
        Future<Process> tryPort([int? port]) async {
          var process = await ChromiumBasedBrowser.chrome.spawn(
            url,
            configuration,
            settings: settings,
            additionalArgs: [
              if (port != null)
                // Chrome doesn't provide any way of ensuring that this port was
                // successfully bound. It produces an error if the binding fails,
                // but without a reliable and fast way to tell if it succeeded
                // that doesn't provide us much. It's very unlikely that this port
                // will fail, though.
                '--remote-debugging-port=$port',
            ],
          );
          debugPortCompleter.complete(port);
          return process;
        }

        if (!configuration.debug) return tryPort();
        return getUnusedPort<Process>(tryPort);
      },
      url,
      debugPortCompleter.future,
    );
  }

  /// Returns a Dart based hit-map containing coverage report, suitable for use
  /// with `package:coverage`.
  Future<Map<String, dynamic>> gatherCoverage() async {
    var tabConnection = (await _connection)?.$1;
    if (tabConnection == null) return {};
    var response = await tabConnection.debugger.connection.sendCommand(
      'Profiler.takePreciseCoverage',
      {},
    );
    var result = (response.result!['result'] as List)
        .cast<Map<String, dynamic>>();
    var httpClient = HttpClient();
    var coverage = await parseChromeCoverage(
      result,
      (scriptId) => _sourceProvider(scriptId, httpClient),
      (scriptId) => _sourceMapProvider(scriptId, httpClient),
      _sourceUriProvider,
    );
    httpClient.close(force: true);
    return coverage;
  }

  Chrome._(super.startBrowser, this._url, this._debugPort);

  /// Connects to the test tab through the DevTools protocol and starts
  /// collecting coverage.
  ///
  /// Returns `null` if Chrome was started without a remote debugging port.
  Future<(WipConnection, Uri)?> _connect() async {
    var port = await _debugPort;
    if (port == null) return null;

    // Wait for Chrome to be in a ready state.
    await output.firstWhere((line) => line.startsWith('DevTools listening'));

    var chromeConnection = ChromeConnection('localhost', port);
    // The browser opens a redirect page first, so the tab can take a while to
    // reach [_url] on a heavily loaded machine. Wait up to about 20 seconds.
    ChromeTab? tab;
    var attempt = 0;
    while (tab == null) {
      attempt++;
      var tabs = await chromeConnection.getTabs();
      tab = tabs.firstWhereOrNull((tab) => tab.url == _url.toString());
      if (tab == null) {
        if (attempt >= 100) {
          throw StateError(
            'Could not connect to test tab with url: $_url\n'
            'Open tabs: ${tabs.map((tab) => tab.url).join(', ')}',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    var tabConnection = await tab.connect();

    // Coverage reports are in terms of scriptIds so keep note of URLs.
    // Register the listener before enabling the debugger so that initial
    // script events sent during initialization are not missed.
    tabConnection.debugger.onScriptParsed.listen((data) {
      var script = data.script;
      if (script.url.isNotEmpty) _idToUrl[script.scriptId] = script.url;
    });

    // Enable debugging.
    await tabConnection.debugger.enable();

    // Enable coverage collection.
    await tabConnection.debugger.connection.sendCommand('Profiler.enable', {});
    await tabConnection.debugger.connection.sendCommand(
      'Profiler.startPreciseCoverage',
      {'detailed': true, 'callCount': false},
    );

    var base = Uri.http('localhost:$port');
    var devtoolsUrl = tab.devtoolsFrontendUrl;
    var remoteDebuggerUrl = devtoolsUrl != null
        ? base.resolve(devtoolsUrl)
        : base;
    return (tabConnection, remoteDebuggerUrl);
  }

  Future<Uri?> _sourceUriProvider(String sourceUrl, String scriptId) async {
    var script = _idToUrl[scriptId];
    if (script == null) return null;
    var sourceUri = Uri.parse(sourceUrl);
    if (sourceUri.scheme == 'file') return sourceUri;
    // If the provided sourceUrl is relative, determine the package path.
    var uri = Uri.parse(script);
    var path = p.join(
      p.joinAll(uri.pathSegments.sublist(1, uri.pathSegments.length - 1)),
      sourceUrl,
    );
    return path.contains('/packages/')
        ? Uri(scheme: 'package', path: path.split('/packages/').last)
        : null;
  }

  Future<String?> _sourceMapProvider(
    String scriptId,
    HttpClient httpClient,
  ) async {
    var script = _idToUrl[scriptId];
    if (script == null) return null;
    return await httpClient.getString('$script.map');
  }

  Future<String?> _sourceProvider(
    String scriptId,
    HttpClient httpClient,
  ) async {
    var script = _idToUrl[scriptId];
    if (script == null) return null;
    return await httpClient.getString(script);
  }
}

extension on HttpClient {
  Encoding determineEncoding(HttpHeaders headers) {
    final contentType = headers.contentType?.charset;

    /// Using the `charset` property of the `contentType` if available.
    /// If it's unavailable or if the encoding name is unknown, [latin1] is used by default,
    /// as per [RFC 2616][].
    ///
    /// [RFC 2616]: http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html
    return Encoding.getByName(contentType) ?? latin1;
  }

  Future<String?> getString(String url) async {
    final request = await getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;
    var bytes = [await for (var chunk in response) ...chunk];
    final encoding = determineEncoding(response.headers);
    return encoding.decode(bytes);
  }
}
