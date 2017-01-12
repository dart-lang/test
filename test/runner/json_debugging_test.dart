// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:async';
import 'dart:convert';

import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:vm_service_client/vm_service_client.dart';
import 'package:web_socket_channel/io.dart';

import 'package:test/src/runner/version.dart';

import '../io.dart';

void main() {
  useSandbox();

  test("waits for a resume command to start running tests", () {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart", "--pause-after-load"], reporter: "json");
    var client = _connectClient(test);

    // Wait for the virtual test that loads the suite to complete.
    test.stdout.expect(consumeThrough(_jsonContainsPair("type", "testDone")));

    schedule(() async {
      // The group event is emitted before the TestStartEvents.
      var testStarted = false;
      var testStartedFuture = test.stdout.next().then((line) {
        expect(line, _jsonContainsPair("type", "group"));
        testStarted = true;
      });

      // Wait a little bit to ensure that the first test hasn't started
      // running.
      await new Future.delayed(new Duration(seconds: 1));
      expect(testStarted, isFalse);

      // Once we send "resume", the test should finish.
      await (await client).sendRequest("resume");
      await (await client).close();
      await testStartedFuture;
    });

    test.stdout.expect(consumeThrough(_jsonContainsPair("type", "done")));
    test.shouldExit();
  });

  test("restarts the test after a restartTest command", () {
    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {
          expect(true, isTrue);
        });
      }
    """).create();

    var test = runTest(["test.dart", "--pause-after-load"], reporter: "json");
    var client = _connectClient(test);

    test.stdout.expect(consumeWhile(isNot(_jsonContainsPair("type", "debug"))));

    schedule(() async {
      var debug = JSON.decode(await test.stdout.next());
      var vmServiceClient = new VMServiceClient.connect(debug["observatory"]);
      var isolate = await (await vmServiceClient.getVM()).isolates
          .firstWhere((isolate) => isolate.name == "test.dart")
          .loadRunnable();
      var library = await isolate.libraries.values
          .firstWhere((value) => value.uri.path.endsWith("/test.dart"))
          .load();
      var breakpoint = await library.scripts.single.addBreakpoint(6);

      // Resuming the isolate should also resume the test runner.
      await isolate.waitUntilPaused();
      await isolate.resume();

      // Wait for the breakpoint to be hit.
      await breakpoint.onPause.first;
      await breakpoint.remove();

      // Restart the test.
      await (await client).sendRequest("restartTest");
      await (await client).close();

      await isolate.resume();
      await vmServiceClient.close();
    });

    // The success test should run twice, since we restart it in the middle.
    test.stdout.expect(inOrder([
      consumeThrough(allOf([
        _jsonContainsPair("type", "testStart"),
        _jsonContainsPair("test", containsPair("name", "success")),
      ])),
      consumeThrough(allOf([
        _jsonContainsPair("type", "testStart"),
        _jsonContainsPair("test", containsPair("name", "success")),
      ])),
      consumeThrough(_jsonContainsPair("type", "done")),
    ]));

    test.shouldExit();
  });
}

/// Schedules a client connection to the web socket client emitted by [test].
Future<rpc.Client> _connectClient(ScheduledProcess test) => schedule(() async {
  var start = JSON.decode(await test.stdout.next());
  expect(start, containsPair("type", "start"));
  var channel = new IOWebSocketChannel.connect(await start["controllerUrl"]);
  var client = new rpc.Client(channel);
  client.listen();
  return client;
});

/// Returns a matcher that verifies that the value is a JSON-encoded map with
/// the given [key] and [value].
Matcher _jsonContainsPair(String key, value) => predicate((line) {
  var valueMatcher = wrapMatcher(value);
  try {
    var object = JSON.decode(line);
    return object is Map && valueMatcher.matches(object[key], {});
  } on FormatException {
    return false;
  }
}, 'contains "$key": $value');

