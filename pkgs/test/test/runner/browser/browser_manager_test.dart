// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm && !windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/src/runner/browser/browser_manager.dart';
import 'package:test/src/runner/executable_settings.dart';
import 'package:test/src/util/one_off_handler.dart';
import 'package:test/test.dart';
import 'package:test_api/backend.dart';
import 'package:test_core/src/runner/configuration.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late OneOffHandler handler;
  late HttpServer server;
  late ExecutableSettings fakeFirefox;

  setUp(() async {
    handler = OneOffHandler();
    server = await shelf_io.serve(handler.handler, 'localhost', 0);
    addTearDown(() => server.close(force: true));

    // A browser that starts but never loads the page it is given, and takes a
    // moment to exit when it is closed.
    var script = p.join(d.sandbox, 'fake_firefox.sh');
    await d.file('fake_firefox.sh', '''
#!/bin/sh
trap 'sleep 1; exit 0' TERM
while :; do sleep 0.1; done
''').create();
    await Process.run('chmod', ['+x', script]);
    fakeFirefox = ExecutableSettings(
      linuxExecutable: script,
      macOSExecutable: script,
    );
  });

  test('ignores a late connection from a browser that timed out', () async {
    var attemptUrls = StreamController<Uri>();
    var attempts = StreamQueue(attemptUrls.stream);

    var managerFuture = BrowserManager.start(
      Runtime.firefox,
      () {
        var completer = Completer<WebSocketChannel>();
        var path = handler.create(
          webSocketHandler((WebSocketChannel ws, _) {
            completer.complete(ws);
          }),
        );
        attemptUrls.add(Uri.parse('ws://localhost:${server.port}/$path'));
        return (
          hostUrl: Uri.parse('http://localhost:${server.port}/'),
          webSocket: completer.future,
        );
      },
      fakeFirefox,
      Configuration.empty,
      connectTimeout: const Duration(seconds: 2),
    );
    var managerStarted = false;
    managerFuture.then((_) => managerStarted = true).ignore();

    var firstUrl = await attempts.next;
    // The second attempt starts once the first one has timed out.
    var secondUrl = await attempts.next;

    // The first browser connects after it was closed, but before it exits.
    var lateConnection = WebSocketChannel.connect(firstUrl);
    await lateConnection.ready;
    expect(
      await lateConnection.stream.isEmpty,
      isTrue,
      reason: 'The late connection should be closed without any messages.',
    );
    expect(managerStarted, isFalse);

    var connection = WebSocketChannel.connect(secondUrl);
    await connection.ready;
    var manager = await managerFuture;
    addTearDown(manager.close);
    expect(connection.closeCode, isNull);
  });
}
