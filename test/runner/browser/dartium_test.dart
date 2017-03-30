// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
@Tags(const ["dartium"])
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/runner/browser/dartium.dart';

import '../../io.dart';
import '../../utils.dart';
import 'code_server.dart';

void main() {
  useSandbox();

  test("starts Dartium with the given URL", () {
    var server = new CodeServer();

    schedule(() async {
      var dartium = new Dartium(await server.url);
      currentSchedule.onComplete.schedule(() async => (await dartium).close());
    });

    server.handleDart('''
var webSocket = new WebSocket(
    window.location.href.replaceFirst("http://", "ws://"));
await webSocket.onOpen.first;
webSocket.send("loaded!");
''');

    var webSocket = server.handleWebSocket();

    schedule(() async {
      expect(await (await webSocket).stream.first, equals("loaded!"));
    });
  });

  test("a process can be killed synchronously after it's started", () async {
    var server = new CodeServer();

    schedule(() async {
      var dartium = new Dartium(await server.url);
      await dartium.close();
    });
  });

  test("reports an error in onExit", () {
    var dartium =
        new Dartium("http://dart-lang.org", executable: "_does_not_exist");
    expect(
        dartium.onExit,
        throwsA(isApplicationException(
            startsWith("Failed to run Dartium: $noSuchFileMessage"))));
  });

  test("can run successful tests", () {
    d
        .file(
            "test.dart",
            """
import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""")
        .create();

    var test = runTest(["-p", "dartium", "test.dart"]);
    test.stdout.fork().expect(never(contains("Compiling")));
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  test("can run failing tests", () {
    d
        .file(
            "test.dart",
            """
import 'package:test/test.dart';

void main() {
  test("failure", () => throw new TestFailure("oh no"));
}
""")
        .create();

    var test = runTest(["-p", "dartium", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
    test.shouldExit(1);
  });
}
