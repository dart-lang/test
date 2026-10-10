// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm && !windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/src/runner/browser/browser_manager.dart';
import 'package:test/src/runner/browser/request_log.dart';
import 'package:test/src/runner/executable_settings.dart';
import 'package:test/test.dart';
import 'package:test_api/backend.dart';
import 'package:test_core/src/runner/configuration.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../utils.dart';

void main() {
  test('reports every attempt when the browser never connects', () async {
    var scriptFile = p.join(d.sandbox, 'fake_firefox.sh');
    await d.file('fake_firefox.sh', '''
#!/bin/sh
echo "fake firefox started"
exec sleep 60
''').create();
    await Process.run('chmod', ['+x', scriptFile]);

    var webSocketUrl = Uri.parse('ws://localhost:1234/secret/0');
    var hostUrl = Uri.parse(
      'http://localhost:1234/secret/index.html',
    ).replace(queryParameters: {'managerUrl': '$webSocketUrl'});
    var requestLog = BrowserRequestLog();

    var manager = BrowserManager.start(
      Runtime.firefox,
      hostUrl,
      Completer<WebSocketChannel>().future,
      ExecutableSettings(
        linuxExecutable: scriptFile,
        macOSExecutable: scriptFile,
      ),
      Configuration.empty,
      requestLog: requestLog,
      connectTimeout: const Duration(seconds: 1),
    );

    // Simulate the first browser loading the host page.
    await requestLog.wrap((_) => shelf.Response.ok(''))(
      shelf.Request('GET', hostUrl),
    );

    await expectLater(
      manager,
      throwsA(
        isApplicationException(
          allOf([
            startsWith('Timed out waiting for Firefox to connect.\n'),
            stringContainsInOrder([
              'Attempt 1 of 3: no connection after ',
              'Process: pid ',
              ', still running',
              'Command: $scriptFile --profile ',
              'redirect.html --no-remote',
              'Requests:\n    index.html (200) after ',
              'Browser output:\n    fake firefox started',
              'Attempt 2 of 3',
              'Requests: none',
              'Attempt 3 of 3',
              'Requests: none',
            ]),
          ]),
        ),
      ),
    );
  });
}
