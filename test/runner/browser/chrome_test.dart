// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")
@Tags(const ["chrome"])
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:test/src/runner/browser/chrome.dart';

import '../../io.dart';
import '../../utils.dart';
import 'code_server.dart';

void main() {
  useSandbox();

  test("starts Chrome with the given URL", () {
    var server = new CodeServer();

    schedule(() async {
      var chrome = new Chrome(await server.url);
      currentSchedule.onComplete.schedule(() async => (await chrome).close());
    });

    server.handleJavaScript('''
var webSocket = new WebSocket(window.location.href.replace("http://", "ws://"));
webSocket.addEventListener("open", function() {
  webSocket.send("loaded!");
});
''');

    var webSocket = server.handleWebSocket();

    schedule(() async {
      expect(await (await webSocket).stream.first, equals("loaded!"));
    });
  },
      // It's not clear why, but this test in particular seems to time out
      // when run in parallel with many other tests.
      timeout: new Timeout.factor(2));

  test("a process can be killed synchronously after it's started", () async {
    var server = new CodeServer();

    schedule(() async {
      var chrome = new Chrome(await server.url);
      await chrome.close();
    });
  });

  test("reports an error in onExit", () {
    var chrome =
        new Chrome("http://dart-lang.org", executable: "_does_not_exist");
    expect(
        chrome.onExit,
        throwsA(isApplicationException(
            startsWith("Failed to run Chrome: $noSuchFileMessage"))));
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

    var test = runTest(["-p", "chrome", "test.dart"]);
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

    var test = runTest(["-p", "chrome", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
    test.shouldExit(1);
  });
}
