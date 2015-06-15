// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm && mac-os")

import 'dart:async';

import 'package:test/test.dart';
import 'package:test/src/runner/browser/safari.dart';
import 'package:test/src/util/io.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../../io.dart';
import '../../utils.dart';

void main() {
  group("running JavaScript", () {
    // The JavaScript to serve in the server. We use actual JavaScript here to
    // avoid the pain of compiling to JS in a test
    var javaScript;

    var servePage = (request) {
      var path = request.url.path;

      // We support both shelf 0.5.x and 0.6.x. The former has a leading "/"
      // here, the latter does not.
      if (path.startsWith("/")) path = path.substring(1);

      if (path.isEmpty) {
        return new shelf.Response.ok("""
<!doctype html>
<html>
<head>
  <script src="index.js"></script>
</head>
</html>
""", headers: {'content-type': 'text/html'});
      } else if (path == "index.js") {
        return new shelf.Response.ok(javaScript,
            headers: {'content-type': 'application/javascript'});
      } else {
        return new shelf.Response.notFound(null);
      }
    };

    var server;
    var webSockets;
    setUp(() async {
      var webSocketsController = new StreamController();
      webSockets = webSocketsController.stream;

      server = await shelf_io.serve(
          new shelf.Cascade()
              .add(webSocketHandler(webSocketsController.add))
              .add(servePage).handler,
          'localhost', 0);
    });

    tearDown(() {
      if (server != null) server.close();

      javaScript = null;
      server = null;
      webSockets = null;
    });

    test("starts Safari with the given URL", () async {
      javaScript = '''
var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send("loaded!");
});
''';
      var safari = new Safari(baseUrlForAddress(server.address, server.port));

      try {
        var message = await (await webSockets.first).first;
        expect(message, equals("loaded!"));
      } finally {
        safari.close();
      }
    });

    test("doesn't preserve state across runs", () {
      javaScript = '''
localStorage.setItem("data", "value");

var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send("done");
});
''';
      var safari = new Safari(baseUrlForAddress(server.address, server.port));

      var first = true;
      webSockets.listen(expectAsync((webSocket) {
        if (first) {
          // The first request will set local storage data. We can't kill the
          // old safari and start a new one until we're sure that that has
          // finished.
          webSocket.first.then((_) {
            safari.close();

            javaScript = '''
var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send(localStorage.getItem("data"));
});
''';
            safari = new Safari(baseUrlForAddress(server.address, server.port));
            first = false;
          });
        } else {
          // The second request will return the local storage data. This should
          // be null, indicating that no data was saved between runs.
          expect(
              webSocket.first
                  .then((message) => expect(message, equals('null')))
                  .whenComplete(safari.close),
              completes);
        }
      }, count: 2));
    });
  });

  test("a process can be killed synchronously after it's started", () async {
    var server = await shelf_io.serve(
        expectAsync((_) {}, count: 0), 'localhost', 0);

    try {
      var safari = new Safari(baseUrlForAddress(server.address, server.port));
      await safari.close();
    } finally {
      server.close();
    }
  });

  test("reports an error in onExit", () {
    var safari = new Safari("http://dart-lang.org",
        executable: "_does_not_exist");
    expect(safari.onExit, throwsA(isApplicationException(startsWith(
        "Failed to run Safari: $noSuchFileMessage"))));
  });
}
