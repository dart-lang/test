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

final _webSocketUrl = Uri.parse('ws://localhost:1234/secret/0');
final _hostUrl = Uri.parse(
  'http://localhost:1234/secret/index.html',
).replace(queryParameters: {'managerUrl': '$_webSocketUrl'});

/// A fake browser script body that writes output and then exits with an error.
const _crash = '''
echo "fake firefox crashed"
exit 1''';

/// Writes an executable fake Firefox script running [body] and returns
/// settings that launch it.
Future<ExecutableSettings> _fakeFirefox(String body) async {
  var scriptFile = p.join(d.sandbox, 'fake_firefox.sh');
  await d.file('fake_firefox.sh', '#!/bin/sh\n$body\n').create();
  await Process.run('chmod', ['+x', scriptFile]);
  return ExecutableSettings(
    linuxExecutable: scriptFile,
    macOSExecutable: scriptFile,
  );
}

/// Starts a browser manager for a fake Firefox that never connects.
Future<BrowserManager> _start(
  ExecutableSettings settings, {
  BrowserRequestLog? requestLog,
  Duration? connectTimeout,
}) => BrowserManager.start(
  Runtime.firefox,
  _hostUrl,
  Completer<WebSocketChannel>().future,
  settings,
  Configuration.empty,
  requestLog: requestLog,
  connectTimeout: connectTimeout,
);

void main() {
  test('reports the attempt when the browser times out', () async {
    var settings = await _fakeFirefox('''
echo "fake firefox started"
exec sleep 60''');
    var requestLog = BrowserRequestLog();

    var manager = _start(
      settings,
      requestLog: requestLog,
      connectTimeout: const Duration(seconds: 1),
    );

    // Simulate the browser loading the host page.
    await requestLog.wrap((_) => shelf.Response.ok(''))(
      shelf.Request('GET', _hostUrl),
    );

    await expectLater(
      manager,
      throwsA(
        isApplicationException(
          allOf([
            startsWith('Timed out waiting for Firefox to connect.\n'),
            stringContainsInOrder([
              'Attempt 1: no connection after ',
              'Process: pid ',
              ', still running',
              'Command: ${settings.executable} --profile ',
              'redirect.html --no-remote',
              'Requests:\n    index.html (200) after ',
              'Browser output:\n    fake firefox started',
            ]),
            // A timeout uses the whole budget, so there is no second attempt.
            isNot(contains('Attempt 2')),
          ]),
        ),
      ),
    );
  });

  test('replaces a browser that exits before connecting', () async {
    var countFile = p.join(d.sandbox, 'count');
    // The first browser exits right away and the second never connects.
    var settings = await _fakeFirefox('''
if [ -e "$countFile" ]; then exec sleep 60; fi
touch "$countFile"
$_crash''');

    await expectLater(
      _start(settings, connectTimeout: const Duration(seconds: 2)),
      throwsA(
        isApplicationException(
          allOf([
            startsWith('Timed out waiting for Firefox to connect.\n'),
            stringContainsInOrder([
              'Attempt 1: exited before connecting after ',
              'exited with code 1',
              'fake firefox crashed',
              'Attempt 2: no connection after ',
              ', still running',
            ]),
          ]),
        ),
      ),
    );
  });

  test(
    'reports every attempt when each browser exits before connecting',
    () async {
      var settings = await _fakeFirefox(_crash);

      await expectLater(
        _start(settings),
        throwsA(
          isApplicationException(
            allOf([
              startsWith('Firefox exited before connecting.\n'),
              stringContainsInOrder([
                'Attempt 1: exited before connecting after ',
                'exited with code 1',
                'fake firefox crashed',
                'Attempt 2: exited before connecting after ',
                'Attempt 3: exited before connecting after ',
              ]),
              isNot(contains('Attempt 4')),
            ]),
          ),
        ),
      );
    },
  );

  test('does not retry a browser that fails to start', () async {
    var missing = p.join(d.sandbox, 'does_not_exist');

    await expectLater(
      _start(
        ExecutableSettings(linuxExecutable: missing, macOSExecutable: missing),
      ),
      throwsA(
        isApplicationException(
          allOf([
            startsWith('Failed to run Firefox: '),
            isNot(contains('Attempt')),
          ]),
        ),
      ),
    );
  });
}
