// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/fake.dart';
import 'package:test/test.dart';
import 'package:test_core/src/runner/console.dart';
import 'package:test_core/src/util/io.dart';

class _FakeStdin extends StreamView<List<int>> with Fake implements Stdin {
  _FakeStdin(super.stream);
}

class _FakeStdout extends Fake implements Stdout {
  final buffer = StringBuffer();

  @override
  void write(Object? object) {
    buffer.write(object);
  }

  @override
  void writeln([Object? object = '']) {
    buffer.writeln(object);
  }
}

void main() {
  late StreamController<List<int>> stdinController;
  late _FakeStdin fakeStdin;
  late _FakeStdout fakeStdout;

  setUp(() {
    stdinController = StreamController<List<int>>();
    fakeStdin = _FakeStdin(stdinController.stream);
    fakeStdout = _FakeStdout();
    addTearDown(() async {
      final hadListener = stdinController.hasListener;
      cancelStdinLines();
      if (hadListener) {
        await stdinController.close();
      } else {
        unawaited(stdinController.close());
      }
    });
  });

  test(
    'stopping an active console twice writes only one newline',
    () => IOOverrides.runZoned(
      () {
        var console = Console(color: false);
        console.stop();
        expect(fakeStdout.buffer.toString(), '');

        console.start();
        expect(fakeStdout.buffer.toString(), '> ');

        console.stop();
        expect(fakeStdout.buffer.toString(), '> \n');

        console.stop();
        expect(fakeStdout.buffer.toString(), '> \n');
      },
      stdin: () => fakeStdin,
      stdout: () => fakeStdout,
    ),
  );

  test(
    'can restart and run commands after stopping',
    () => IOOverrides.runZoned(
      () async {
        var pinged = Completer<void>();
        var console = Console(color: false)
          ..registerCommand('ping', 'Ping', pinged.complete);

        console.start();
        expect(fakeStdout.buffer.toString(), '> ');

        console.stop();
        expect(fakeStdout.buffer.toString(), '> \n');

        console.start();
        expect(fakeStdout.buffer.toString(), '> \n> ');

        stdinController.add(utf8.encode('ping\n'));
        await pinged.future;
        await pumpEventQueue();
        expect(fakeStdout.buffer.toString(), '> \n> > ');

        console.stop();
        console.stop();
        expect(fakeStdout.buffer.toString(), '> \n> > \n');
      },
      stdin: () => fakeStdin,
      stdout: () => fakeStdout,
    ),
  );
}
