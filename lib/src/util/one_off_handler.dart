// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.one_off_handler;

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;

/// A Shelf handler that provides support for one-time handlers.
///
/// This is useful for handlers that only expect to be hit once before becoming
/// invalid and don't need to have a persistent URL.
class OneOffHandler {
  /// A map from URL paths to handlers.
  final _handlers = new Map<String, shelf.Handler>();

  /// The counter of handlers that have been activated.
  var _counter = 0;

  /// The actual [shelf.Handler] that dispatches requests.
  shelf.Handler get handler => _onRequest;

  /// Creates a new one-off handler that forwards to [handler].
  ///
  /// Returns a string that's the URL path for hitting this handler, relative to
  /// the URL for the one-off handler itself.
  ///
  /// [handler] will be unmounted as soon as it receives a request.
  String create(shelf.Handler handler) {
    var path = _counter.toString();
    _handlers[path] = handler;
    _counter++;
    return path;
  }

  /// Dispatches [request] to the appropriate handler.
  _onRequest(shelf.Request request) {
    var components = p.url.split(request.url.path);

    // For shelf < 0.6.0, the first component of the path is always "/". We can
    // safely skip it.
    if (components.isNotEmpty && components.first == "/") {
      components.removeAt(0);
    }

    if (components.isEmpty) return new shelf.Response.notFound(null);

    var handler = _handlers.remove(components.removeAt(0));
    if (handler == null) return new shelf.Response.notFound(null);
    return handler(request);
  }
}
