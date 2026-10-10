// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf/shelf.dart' as shelf;

/// Records the requests browsers make while they connect to the test runner,
/// so that a connection timeout can report how far a browser got.
///
/// Only requests that can be tied to a browser manager are recorded: the host
/// page, which carries the manager's WebSocket URL in its `managerUrl` query
/// parameter, resources loaded by the host page, which carry it in their
/// `Referer`, and WebSocket upgrades.
class BrowserRequestLog {
  /// The maximum number of requests to remember.
  static const _maxRequests = 1000;

  final _requests = <_LoggedRequest>[];

  /// Middleware that records requests to the wrapped handler.
  shelf.Handler wrap(shelf.Handler inner) => (request) async {
    var entry = _entryFor(request);
    if (entry == null) return inner(request);

    _requests.add(entry);
    if (_requests.length > _maxRequests) _requests.removeAt(0);
    try {
      var response = await inner(request);
      entry.result = '${response.statusCode}';
      return response;
    } on shelf.HijackException {
      entry.result = 'upgraded';
      rethrow;
    } catch (error) {
      entry.result = 'error: $error';
      rethrow;
    }
  };

  /// Describes the requests made on behalf of the browser manager connecting
  /// to [webSocketUrl] since [since], one line per request.
  List<String> describe(Uri webSocketUrl, DateTime since) => [
    for (var request in _requests)
      if (request.managerKey == webSocketUrl.toString() ||
          request.managerKey == webSocketUrl.path)
        if (!request.time.isBefore(since))
          '${request.label} (${request.result ?? 'pending'}) after '
              '${_seconds(request.time.difference(since))}',
  ];

  _LoggedRequest? _entryFor(shelf.Request request) {
    var time = DateTime.now();
    var label = request.url.pathSegments.lastOrNull ?? '/';
    if (request.headers['upgrade']?.toLowerCase() == 'websocket') {
      return _LoggedRequest(
        time,
        'WebSocket upgrade',
        request.requestedUri.path,
      );
    }
    var managerUrl = request.requestedUri.queryParameters['managerUrl'];
    if (managerUrl != null) return _LoggedRequest(time, label, managerUrl);

    var referer = Uri.tryParse(request.headers['referer'] ?? '');
    var refererManagerUrl = referer?.queryParameters['managerUrl'];
    if (refererManagerUrl != null) {
      return _LoggedRequest(time, label, refererManagerUrl);
    }
    return null;
  }
}

String _seconds(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';

class _LoggedRequest {
  final DateTime time;

  /// A short description of the request, without the server's secret path.
  final String label;

  /// The WebSocket URL, or for upgrades the path, of the browser manager this
  /// request belongs to.
  final String managerKey;

  /// The response status, or another description of how the request ended.
  String? result;

  _LoggedRequest(this.time, this.label, this.managerKey);
}
