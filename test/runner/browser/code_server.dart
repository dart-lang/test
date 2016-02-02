// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http_parser/http_parser.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:scheduled_test/scheduled_server.dart';

/// A class that schedules a server to serve Dart and/or JS code and receive
/// WebSocket connections.
///
/// This uses [ScheduledServer] under the hood, and has similar semantics: its
/// `handle*` methods all schedule a handler that must be hit before the
/// schedule will continue.
class CodeServer {
  /// The underlying server.
  final ScheduledServer _server;

  /// The URL of the server (including the port), once it's actually
  /// instantiated.
  Future<Uri> get url => _server.url;

  /// The port of the server, once it's actually instantiated.
  Future<int> get port => _server.port;

  CodeServer()
      : _server = new ScheduledServer("code server") {
    _server.handleUnscheduled("GET", "/favicon.ico",
        (_) => new shelf.Response.notFound(null));
  }

  /// Sets up a handler for the root of the server, "/", that serves a basic
  /// HTML page with a script tag that will run [dart].
  void handleDart(String dart) {
    _server.handle("GET", "/", (_) {
      return new shelf.Response.ok("""
<!doctype html>
<html>
<head>
  <script type="application/dart" src="index.dart"></script>
</head>
</html>
""", headers: {'content-type': 'text/html'});
    });

    _server.handle("GET", "/index.dart", (_) {
      return new shelf.Response.ok('''
import "dart:html";

main() async {
  $dart
}
''', headers: {'content-type': 'application/dart'});
    });
  }

  /// Sets up a handler for the root of the server, "/", that serves a basic
  /// HTML page with a script tag that will run [javaScript].
  void handleJavaScript(String javaScript) {
    _server.handle("GET", "/", (_) {
      return new shelf.Response.ok("""
<!doctype html>
<html>
<head>
  <script src="index.js"></script>
</head>
</html>
""", headers: {'content-type': 'text/html'});
    });

    _server.handle("GET", "/index.js", (_) {
      return new shelf.Response.ok(javaScript,
          headers: {'content-type': 'application/javascript'});
    });
  }

  /// Handles a WebSocket connection to the root of the server, and returns a
  /// future that will complete to the WebSocket.
  Future<WebSocketChannel> handleWebSocket() {
    var completer = new Completer();
    _server.handle("GET", "/", webSocketHandler(completer.complete));
    return completer.future;
  }
}
