// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/src/runner/browser/content_shell.dart';
import 'package:test/src/util/io.dart';
import 'package:test/src/utils.dart';
import 'package:test/test.dart';

import '../../utils.dart';

void main() {
  group("running Dart", () {
    // The Dart to serve in the server.
    var dart;

    var servePage = (request) {
      var path = shelfUrl(request).path;

      if (path.isEmpty) {
        return new shelf.Response.ok("""
<!doctype html>
<html>
<head>
  <script type="application/dart" src="index.dart"></script>
</head>
</html>
""", headers: {'content-type': 'text/html'});
      } else if (path == "index.dart") {
        return new shelf.Response.ok('''
import "dart:js" as js;
import "dart:html";

void main() {
  js.context['testRunner'].callMethod('waitUntilDone', []);

  $dart
}
''', headers: {'content-type': 'application/dart'});
      } else {
        return new shelf.Response.notFound(null);
      }
    };

    var server;
    var webSockets;
    setUp(() {
      var webSocketsController = new StreamController();
      webSockets = webSocketsController.stream;

      return shelf_io.serve(
          new shelf.Cascade()
              .add(webSocketHandler(webSocketsController.add))
              .add(servePage).handler,
          'localhost', 0).then((server_) {
        server = server_;
      });
    });

    tearDown(() {
      if (server != null) server.close();

      dart = null;
      server = null;
      webSockets = null;
    });

    test("starts content shell with the given URL", () {
      dart = '''
var webSocket = new WebSocket(
    window.location.href.replaceFirst("http://", "ws://"));
webSocket.onOpen.first.then((_) => webSocket.send("loaded!"));
''';
      var contentShell = new ContentShell(
          baseUrlForAddress(server.address, server.port));

      return webSockets.first.then((webSocket) {
        return webSocket.first.then(
            (message) => expect(message, equals("loaded!")));
      }).whenComplete(contentShell.close);
    });

    test("doesn't preserve state across runs", () {
      dart = '''
window.localStorage["data"] = "value";

var webSocket = new WebSocket(
    window.location.href.replaceFirst("http://", "ws://"));
webSocket.onOpen.first.then((_) => webSocket.send("done"));
''';
      var contentShell = new ContentShell(
          baseUrlForAddress(server.address, server.port));

      var first = true;
      webSockets.listen(expectAsync((webSocket) {
        if (first) {
          // The first request will set local storage data. We can't kill the
          // old content shell and start a new one until we're sure that that
          // has finished.
          webSocket.first.then((_) {
            contentShell.close();

            dart = '''
var webSocket = new WebSocket(
    window.location.href.replaceFirst("http://", "ws://"));
webSocket.onOpen.first.then((_) =>
    webSocket.send(window.localStorage["data"].toString()));
''';
            contentShell = new ContentShell(
                baseUrlForAddress(server.address, server.port));
            first = false;
          });
        } else {
          // The second request will return the local storage data. This should
          // be null, indicating that no data was saved between runs.
          expect(
              webSocket.first
                  .then((message) => expect(message, equals('null')))
                  .whenComplete(contentShell.close),
              completes);
        }
      }, count: 2));
    });
  });

  test("a process can be killed synchronously after it's started", () {
    return shelf_io.serve(expectAsync((_) {}, count: 0), 'localhost', 0)
        .then((server) {
      var contentShell = new ContentShell(
          baseUrlForAddress(server.address, server.port));
      return contentShell.close().whenComplete(server.close);
    });
  });

  test("reports an error in onExit", () {
    var contentShell = new ContentShell("http://dart-lang.org",
        executable: "_does_not_exist");
    expect(contentShell.onExit, throwsA(isApplicationException(startsWith(
        "Failed to start content shell: No such file or directory"))));
  });
}
