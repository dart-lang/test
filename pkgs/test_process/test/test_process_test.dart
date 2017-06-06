// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

final throwsTestFailure = throwsA(new isInstanceOf<TestFailure>());

void main() {
  group("shouldExit()", () {
    test("succeeds when the process exits with the given exit code", () async {
      var process = await startDartProcess('exitCode = 42;');
      expect(process.exitCode, completion(equals(42)));
      await process.shouldExit(greaterThan(12));
    });

    test("fails when the process exits with a different exit code", () async {
      var process = await startDartProcess('exitCode = 1;');
      expect(process.exitCode, completion(equals(1)));
      expect(process.shouldExit(greaterThan(12)), throwsTestFailure);
    });

    test("allows any exit code without an assertion", () async {
      var process = await startDartProcess('exitCode = 1;');
      expect(process.exitCode, completion(equals(1)));
      await process.shouldExit();
    });
  });

  test("kill() stops the process", () async {
    var process = await startDartProcess('while (true);');

    // Should terminate.
    await process.kill();
  });

  group("stdout and stderr", () {
    test("expose the process's standard io", () async {
      var process = await startDartProcess(r'''
        print("hello");
        stderr.writeln("hi");
        print("\nworld");
      ''');

      expect(process.stdout,
          emitsInOrder(['hello', '', 'world', emitsDone]));
      expect(process.stderr, emitsInOrder(['hi', emitsDone]));
      await process.shouldExit(0);
    });

    test("close when the process exits", () async {
      var process = await startDartProcess('');
      expect(expectLater(process.stdout, emits('hello')),
          throwsTestFailure);
      expect(expectLater(process.stderr, emits('world')),
          throwsTestFailure);
      await process.shouldExit(0);
    });
  });

  test("stdoutStream() and stderrStream() copy the process's standard io",
      () async {
    var process = await startDartProcess(r'''
      print("hello");
      stderr.writeln("hi");
      print("\nworld");
    ''');

      expect(process.stdoutStream(),
          emitsInOrder(['hello', '', 'world', emitsDone]));
      expect(process.stdoutStream(),
          emitsInOrder(['hello', '', 'world', emitsDone]));

      expect(process.stderrStream(), emitsInOrder(['hi', emitsDone]));
      expect(process.stderrStream(), emitsInOrder(['hi', emitsDone]));

      await process.shouldExit(0);

      expect(process.stdoutStream(),
          emitsInOrder(['hello', '', 'world', emitsDone]));
      expect(process.stderrStream(), emitsInOrder(['hi', emitsDone]));
  });

  test("stdin writes to the process", () async {
    var process = await startDartProcess(r'''
      stdinLines.listen((line) => print("> $line"));
    ''');

    process.stdin.writeln("hello");
    await expectLater(process.stdout, emits("> hello"));
    process.stdin.writeln("world");
    await expectLater(process.stdout, emits("> world"));
    await process.kill();
  });

  test("signal sends a signal to the process", () async {
    var process = await startDartProcess(r'''
      ProcessSignal.SIGHUP.watch().listen((_) => print("HUP"));
      print("ready");
    ''');

    await expectLater(process.stdout, emits('ready'));
    process.signal(ProcessSignal.SIGHUP);
    await expectLater(process.stdout, emits('HUP'));
    process.kill();
  }, testOn: "!windows");
}

/// Starts a Dart process running [script] in a main method.
Future<TestProcess> startDartProcess(String script) {
  var dartPath = p.join(d.sandbox, 'test.dart');
  new File(dartPath).writeAsStringSync('''
    import 'dart:async';
    import 'dart:convert';
    import 'dart:io';

    var stdinLines = stdin
        .transform(UTF8.decoder)
        .transform(new LineSplitter());

    void main() {
      $script
    }
  ''');

  return TestProcess.start(Platform.executable, ['--checked', dartPath]);
}
