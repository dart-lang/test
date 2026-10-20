// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Tags(['chrome'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/runner/browser/chrome.dart';
import 'package:test/src/runner/executable_settings.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';
import '../../utils.dart';
import 'code_server.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test(
    'starts Chrome with the given URL',
    () async {
      var server = await CodeServer.start();

      server.handleJavaScript('''
var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send("loaded!");
});
''');
      var webSocket = server.handleWebSocket();

      var chrome = Chrome(server.url, configuration());
      addTearDown(() => chrome.close());

      expect(await (await webSocket).stream.first, equals('loaded!'));
    },
    // It's not clear why, but this test in particular seems to time out
    // when run in parallel with many other tests.
    timeout: const Timeout.factor(2),
  );

  test("a process can be killed synchronously after it's started", () async {
    var server = await CodeServer.start();
    var chrome = Chrome(server.url, configuration());
    await chrome.close();
  });

  test('reports an error in onExit', () {
    var chrome = Chrome(
      Uri.https('dart.dev'),
      configuration(),
      settings: ExecutableSettings(
        linuxExecutable: '_does_not_exist',
        macOSExecutable: '_does_not_exist',
        windowsExecutable: '_does_not_exist',
      ),
    );
    expect(
      chrome.onExit,
      throwsA(
        isApplicationException(
          startsWith('Failed to run Chrome: $noSuchFileMessage'),
        ),
      ),
    );
  });

  test('can run successful tests', () async {
    await d.file('test.dart', '''
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();

    var test = await runTest(['-p', 'chrome', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test('can run failing tests', () async {
    await d.file('test.dart', '''
import 'package:test/test.dart';

void main() {
  test("failure", () => throw TestFailure("oh no"));
}
''').create();

    var test = await runTest(['-p', 'chrome', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('can override chrome location with CHROME_EXECUTABLE var', () async {
    await d.file('test.dart', '''
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();
    var test = await runTest(
      ['-p', 'chrome', 'test.dart'],
      environment: {'CHROME_EXECUTABLE': '/some/bad/path'},
    );
    expect(test.stdout, emitsThrough(contains('Failed to run Chrome:')));
    await test.shouldExit(1);
  });

  test('does not pass target URL directly in command line arguments', () async {
    var targetUrl = Uri.parse('http://localhost:12345/secret_token_12345');
    var argsFile = p.join(d.sandbox, 'args.txt');
    var scriptFile = p.join(d.sandbox, 'fake_chrome.sh');
    await d.file('fake_chrome.sh', '''
#!/bin/sh
echo "\$@" > "$argsFile"
''').create();
    await Process.run('chmod', ['+x', scriptFile]);

    var chrome = Chrome(
      targetUrl,
      configuration(),
      settings: ExecutableSettings(
        linuxExecutable: scriptFile,
        macOSExecutable: scriptFile,
        windowsExecutable: scriptFile,
      ),
    );
    await chrome.onExit.catchError((_) {});

    var argsText = await File(argsFile).readAsString();
    expect(argsText, isNot(contains('secret_token_12345')));
    expect(argsText, contains('redirect.html'));
  }, testOn: '!windows');

  test('keeps all output when connecting to DevTools', () async {
    // Stands in for the DevTools HTTP server. Responding with something other
    // than JSON makes the connection fail once the tab list is requested.
    var devTools = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(devTools.close);
    var requestedPaths = <String>[];
    devTools.listen((request) {
      requestedPaths.add(request.uri.path);
      request.response
        ..write('not json')
        ..close();
    });
    var devToolsLine =
        'DevTools listening on '
        'ws://127.0.0.1:${devTools.port}/devtools/browser/fake';

    var argsFile = p.join(d.sandbox, 'args.txt');
    var scriptFile = p.join(d.sandbox, 'fake_chrome.sh');
    await d.file('fake_chrome.sh', '''
#!/bin/sh
echo "\$@" > "$argsFile"
echo "$devToolsLine" >&2
echo "stderr after DevTools" >&2
echo "stdout line"
''').create();
    await Process.run('chmod', ['+x', scriptFile]);

    var chrome = Chrome(
      Uri.parse('http://localhost:12345/'),
      configuration(debug: true),
      settings: ExecutableSettings(
        linuxExecutable: scriptFile,
        macOSExecutable: scriptFile,
        windowsExecutable: scriptFile,
      ),
    );
    addTearDown(chrome.close);

    var expected = unorderedEquals([
      devToolsLine,
      'stderr after DevTools',
      'stdout line',
    ]);
    expect(await chrome.output.toList(), expected);
    expect(
      await File(argsFile).readAsString(),
      contains('--remote-debugging-port=0'),
    );
    // Connecting starts only now, after the output has ended, so the port has
    // to come from the "DevTools listening" line in the replayed output.
    await expectLater(chrome.remoteDebuggerUrl, throwsA(isA<IOException>()));
    expect(requestedPaths, ['/json']);
    expect(chrome.accumulatedOutput, expected);
  }, testOn: '!windows');

  test('fails to connect if the DevTools line has no port', () async {
    var devToolsLine =
        'DevTools listening on ws://127.0.0.1/devtools/browser/fake';
    var scriptFile = p.join(d.sandbox, 'fake_chrome.sh');
    await d.file('fake_chrome.sh', '''
#!/bin/sh
echo "$devToolsLine" >&2
''').create();
    await Process.run('chmod', ['+x', scriptFile]);

    var chrome = Chrome(
      Uri.parse('http://localhost:12345/'),
      configuration(debug: true),
      settings: ExecutableSettings(
        linuxExecutable: scriptFile,
        macOSExecutable: scriptFile,
        windowsExecutable: scriptFile,
      ),
    );
    addTearDown(chrome.close);

    await expectLater(
      chrome.remoteDebuggerUrl,
      throwsA(
        isStateError.having(
          (e) => e.message,
          'message',
          'Could not find the DevTools port in: $devToolsLine',
        ),
      ),
    );
  }, testOn: '!windows');
}
