// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@TestOn('vm')
@Tags(['firefox'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/runner/browser/firefox.dart';
import 'package:test/src/runner/executable_settings.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';
import '../../utils.dart';
import 'code_server.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test('starts Firefox with the given URL', () async {
    var server = await CodeServer.start();

    server.handleJavaScript('''
var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send("loaded!");
});
''');
    var webSocket = server.handleWebSocket();

    var firefox = Firefox(server.url);
    addTearDown(() => firefox.close());

    expect(await (await webSocket).stream.first, equals('loaded!'));
  });

  test("a process can be killed synchronously after it's started", () async {
    var server = await CodeServer.start();

    var firefox = Firefox(server.url);
    await firefox.close();
  });

  test('reports an error in onExit', () {
    var firefox = Firefox(
      Uri.https('dart.dev'),
      settings: ExecutableSettings(
        linuxExecutable: '_does_not_exist',
        macOSExecutable: '_does_not_exist',
        windowsExecutable: '_does_not_exist',
      ),
    );
    expect(
      firefox.onExit,
      throwsA(
        isApplicationException(
          startsWith('Failed to run Firefox: $noSuchFileMessage'),
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

    var test = await runTest(['-p', 'firefox', 'test.dart']);
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

    var test = await runTest(['-p', 'firefox', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('can override firefox location with FIREFOX_EXECUTABLE var', () async {
    await d.file('test.dart', '''
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();
    var test = await runTest(
      ['-p', 'firefox', 'test.dart'],
      environment: {'FIREFOX_EXECUTABLE': '/some/bad/path'},
    );
    expect(test.stdout, emitsThrough(contains('Failed to run Firefox:')));
    await test.shouldExit(1);
  });

  test('not impacted by CHROME_EXECUTABLE var', () async {
    await d.file('test.dart', '''
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("success", () {
    assert(window.navigator.vendor != 'Google Inc.');
  });
}
''').create();
    var test = await runTest(
      ['-p', 'firefox', 'test.dart'],
      environment: {'CHROME_EXECUTABLE': '/some/bad/path'},
    );
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test('does not pass target URL directly in command line arguments', () async {
    var targetUrl = Uri.parse('http://localhost:12345/secret_token_12345');
    var argsFile = p.join(d.sandbox, 'args.txt');
    var scriptFile = p.join(d.sandbox, 'fake_firefox.sh');
    await d.file('fake_firefox.sh', '''
#!/bin/sh
echo "\$@" > "$argsFile"
''').create();
    await Process.run('chmod', ['+x', scriptFile]);

    var firefox = Firefox(
      targetUrl,
      settings: ExecutableSettings(
        linuxExecutable: scriptFile,
        macOSExecutable: scriptFile,
        windowsExecutable: scriptFile,
      ),
    );
    await firefox.onExit.catchError((_) {});

    var argsText = await File(argsFile).readAsString();
    expect(argsText, isNot(contains('secret_token_12345')));
    expect(argsText, contains('redirect.html'));
  }, testOn: '!windows');
}
