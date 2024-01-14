// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Tags(['edge'])
library;

import 'package:test/src/runner/browser/microsoft_edge.dart';
import 'package:test/src/runner/executable_settings.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';
import '../../utils.dart';
import 'code_server.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test('starts edge with the given URL', () async {
    var server = await CodeServer.start();

    server.handleJavaScript('''
var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send("loaded!");
});
''');
    var webSocket = server.handleWebSocket();

    var edge = MicrosoftEdge(server.url, configuration());
    addTearDown(() => edge.close());

    expect(await (await webSocket).stream.first, equals('loaded!'));
  }, timeout: const Timeout.factor(2));

  test('reports an error in onExit', () {
    var edge = MicrosoftEdge(Uri.parse('https://dart.dev'), configuration(),
        settings: ExecutableSettings(
            linuxExecutable: '_does_not_exist',
            macOSExecutable: '_does_not_exist',
            windowsExecutable: '_does_not_exist'));
    expect(
        edge.onExit,
        throwsA(isApplicationException(
            startsWith('Failed to run Edge: $noSuchFileMessage'))));
  });

  test('can run successful tests', () async {
    await d.file('test.dart', '''
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();

    var test = await runTest(['-p', 'edge', 'test.dart']);
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

    var test = await runTest(['-p', 'edge', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('can override edge location with MS_EDGE_EXECUTABLE var', () async {
    await d.file('test.dart', '''
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
''').create();
    var test = await runTest(['-p', 'edge', 'test.dart'],
        environment: {'MS_EDGE_EXECUTABLE': '/some/bad/path'});
    expect(test.stdout, emitsThrough(contains('Failed to run Edge:')));
    await test.shouldExit(1);
  });
}
