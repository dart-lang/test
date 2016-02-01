// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Windows doesn't support sending signals.
@TestOn("vm && !windows")

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../io.dart';

String get _tempDir => p.join(sandbox, "tmp");

// This test is inherently prone to race conditions. If it fails, it will likely
// do so flakily, but if it succeeds, it will succeed consistently. The tests
// represent a best effort to kill the test runner at certain times during its
// execution.
void main() {
  useSandbox(() => d.dir("tmp").create());

  group("during loading,", () {
    test("cleans up if killed while loading a VM test", () {
      d.file("test.dart", """
void main() {
  print("in test.dart");
  // Spin for a long time so the test is probably killed while still loading.
  for (var i = 0; i < 100000000; i++) {}
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("in test.dart"));
      signalAndQuit(test);

      expectTempDirEmpty();
    });

    test("cleans up if killed while loading a browser test", () {
      d.file("test.dart", "void main() {}").create();

      var test = _runTest(["-p", "chrome", "test.dart"]);
      test.stdout.expect(consumeThrough(endsWith("compiling test.dart")));
      signalAndQuit(test);

      expectTempDirEmpty();
    });

    test("exits immediately if ^C is sent twice", () {
      d.file("test.dart", """
void main() {
  print("in test.dart");
  while (true) {}
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("in test.dart"));
      test.signal(ProcessSignal.SIGTERM);

      // TODO(nweiz): Sending two signals in close succession can cause the
      // second one to be ignored, so we wait a bit before the second
      // one. Remove this hack when issue 23047 is fixed.
      schedule(() => new Future.delayed(new Duration(seconds: 1)));

      signalAndQuit(test);
    });
  });

  group("during test running", () {
    test("waits for a VM test to finish running", () {
      d.file("test.dart", """
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  tearDownAll(() {
    new File("output_all").writeAsStringSync("ran tearDownAll");
  });

  tearDown(() => new File("output").writeAsStringSync("ran tearDown"));

  test("test", () {
    print("running test");
    return new Future.delayed(new Duration(seconds: 1));
  });
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("running test"));
      signalAndQuit(test);

      d.file("output", "ran tearDown").validate();
      d.file("output_all", "ran tearDownAll").validate();
      expectTempDirEmpty();
    });

    test("waits for an active tearDownAll to finish running", () {
      d.file("test.dart", """
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  tearDownAll(() async {
    print("running tearDownAll");
    await new Future.delayed(new Duration(seconds: 1));
    new File("output").writeAsStringSync("ran tearDownAll");
  });

  test("test", () {});
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("running tearDownAll"));
      signalAndQuit(test);

      d.file("output", "ran tearDownAll").validate();
      expectTempDirEmpty();
    });

    test("kills a browser test immediately", () {
      d.file("test.dart", """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test", () {
    print("running test");

    // Allow an event loop to pass so the preceding print can be handled.
    return new Future(() {
      // Loop forever so that if the test isn't stopped while running, it never
      // stops.
      while (true) {}
    });
  });
}
""").create();

      var test = _runTest(["-p", "content-shell", "test.dart"]);
      test.stdout.expect(consumeThrough("running test"));
      signalAndQuit(test);

      expectTempDirEmpty();
    });

    test("kills a VM test immediately if ^C is sent twice", () {
      d.file("test.dart", """
import 'package:test/test.dart';

void main() {
  test("test", () {
    print("running test");
    while (true) {}
  });
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("running test"));
      test.signal(ProcessSignal.SIGTERM);

      // TODO(nweiz): Sending two signals in close succession can cause the
      // second one to be ignored, so we wait a bit before the second
      // one. Remove this hack when issue 23047 is fixed.
      schedule(() => new Future.delayed(new Duration(seconds: 1)));
      signalAndQuit(test);
    });

    test("causes expect() to always throw an error immediately", () {
      d.file("test.dart", """
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  var expectThrewError = false;

  tearDown(() {
    new File("output").writeAsStringSync(expectThrewError.toString());
  });

  test("test", () async {
    print("running test");

    await new Future.delayed(new Duration(seconds: 1));
    try {
      expect(true, isTrue);
    } catch (_) {
      expectThrewError = true;
    }
  });
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("running test"));
      signalAndQuit(test);

      d.file("output", "true").validate();
      expectTempDirEmpty();
    });

    test("causes expectAsync() to always throw an error immediately", () {
      d.file("test.dart", """
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  var expectAsyncThrewError = false;

  tearDown(() {
    new File("output").writeAsStringSync(expectAsyncThrewError.toString());
  });

  test("test", () async {
    print("running test");

    await new Future.delayed(new Duration(seconds: 1));
    try {
      expectAsync(() {});
    } catch (_) {
      expectAsyncThrewError = true;
    }
  });
}
""").create();

      var test = _runTest(["test.dart"]);
      test.stdout.expect(consumeThrough("running test"));
      signalAndQuit(test);

      d.file("output", "true").validate();
      expectTempDirEmpty();
    });
  });
}

ScheduledProcess _runTest(List<String> args, {bool forwardStdio: false}) =>
    runTest(args,
        environment: {"_UNITTEST_TEMP_DIR": _tempDir},
        forwardStdio: forwardStdio);

void signalAndQuit(ScheduledProcess test) {
  test.signal(ProcessSignal.SIGTERM);
  test.shouldExit();
  test.stderr.expect(isDone);
}

void expectTempDirEmpty() {
  schedule(() => expect(new Directory(_tempDir).listSync(), isEmpty));
}
