// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:test/test.dart';
import 'package:test_api/backend.dart'; // ignore: deprecated_member_use
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(() async {
    await precompileTestExecutable();
  });

  for (var runtime in Runtime.builtIn) {
    // Ignore the platforms we can't run on this OS.
    if (runtime == Runtime.internetExplorer && !Platform.isWindows ||
        runtime == Runtime.safari && !Platform.isMacOS) {
      continue;
    }
    group('--runtime ${runtime.identifier}', () {
      for (var compiler in runtime.supportedCompilers) {
        group('--compiler ${compiler.identifier}', () {
          final testArgs = [
            'test.dart',
            '-p',
            runtime.identifier,
            '-c',
            compiler.identifier
          ];

          test('can run passing tests', () async {
            await d.file('test.dart', _goodTest).create();
            var test = await runTest(testArgs);

            expect(
                test.stdout, emitsThrough(contains('+1: All tests passed!')));
            await test.shouldExit(0);
          });

          test('fails gracefully for invalid code', () async {
            await d.file('test.dart', _compileErrorTest).create();
            var test = await runTest(testArgs);

            expect(
                test.stdout,
                containsInOrder([
                  "Error: A value of type 'String' can't be assigned to a variable of type 'int'.",
                  "int x = 'hello';",
                ]));

            await test.shouldExit(1);
          });

          test('fails gracefully for test failures', () async {
            await d.file('test.dart', _failingTest).create();
            var test = await runTest(testArgs);

            expect(
                test.stdout,
                containsInOrder([
                  'Expected: <2>',
                  'Actual: <1>',
                  'test.dart 5',
                  '+0 -1: Some tests failed.',
                ]));

            await test.shouldExit(1);
          });

          test('fails gracefully if a test file throws in main', () async {
            await d.file('test.dart', _throwingTest).create();
            var test = await runTest(testArgs);
            var compileOrLoadMessage =
                compiler == Compiler.dart2js ? 'compiling' : 'loading';

            expect(
                test.stdout,
                containsInOrder([
                  '-1: [${runtime.name}, ${compiler.name}] $compileOrLoadMessage '
                      'test.dart [E]',
                  'Failed to load "test.dart": oh no'
                ]));
            await test.shouldExit(1);
          });

          test('captures prints', () async {
            await d.file('test.dart', _testWithPrints).create();
            var test = await runTest([...testArgs, '-r', 'json']);

            expect(
                test.stdout,
                containsInOrder([
                  '"messageType":"print","message":"hello","type":"print"',
                ]));

            await test.shouldExit(0);
          });

          test('forwards stdout/stderr', () async {
            await d.file('test.dart', _testWithStdOutAndErr).create();
            var test = await runTest(testArgs);

            expect(test.stdout, emitsThrough('hello'));
            expect(test.stderr, emits('world'));
            await test.shouldExit(0);
          }, testOn: '!browser');
        },
            skip: compiler == Compiler.dart2wasm
                ? 'Wasm tests are experimental and require special setup'
                : null);
      }
    });
  }
}

final _goodTest = '''
  import 'package:test/test.dart';

  void main() {
    test("success", () {});
  }
''';

final _failingTest = '''
  import 'package:test/test.dart';

  void main() {
    test("failure", () {
      expect(1, 2);
    });
  }
''';

final _compileErrorTest = '''
int x = 'hello';

void main() {}
''';

final _throwingTest = "void main() => throw 'oh no';";

final _testWithPrints = '''
import 'package:test/test.dart';

void main() {
  print('hello');
  test('success', () {});
}''';

final _testWithStdOutAndErr = '''
import 'dart:io';
import 'package:test/test.dart';

void main() {
  stdout.writeln('hello');
  stderr.writeln('world');
  test('success', () {});
}''';
