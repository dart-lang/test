// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Timeout.factor(2)
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:test_api/backend.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(() async {
    await precompileTestExecutable();
  });

  for (var runtime in Runtime.builtIn) {
    for (var compiler in runtime.supportedCompilers) {
      final sanitizerSuffix = switch (runtime) {
        Runtime.vmAsan => 'asan',
        Runtime.vmMsan => 'msan',
        Runtime.vmTsan => 'tsan',
        _ => null,
      };
      final sanitizerEnvironment = switch (runtime) {
        Runtime.vmAsan => 'ASAN_OPTIONS',
        Runtime.vmMsan => 'MSAN_OPTIONS',
        Runtime.vmTsan => 'TSAN_OPTIONS',
        _ => null,
      };
      // Ignore the platforms we can't run on this OS.
      if ((runtime == Runtime.edge && !Platform.isWindows) ||
          (runtime == Runtime.safari && !Platform.isMacOS) ||
          (runtime == Runtime.vmAsan && !Platform.isLinux) ||
          (runtime == Runtime.vmMsan && !Platform.isLinux) ||
          (runtime == Runtime.vmTsan && !Platform.isLinux)) {
        continue;
      }
      String? skipReason;
      if (runtime == Runtime.safari) {
        skipReason = 'https://github.com/dart-lang/test/issues/1253';
      } else if (compiler == Compiler.dart2wasm) {
        skipReason = 'Wasm tests are experimental and require special setup';
      } else if ([Runtime.firefox, Runtime.nodeJS].contains(runtime) &&
          Platform.isWindows) {
        skipReason = 'https://github.com/dart-lang/test/issues/1942';
      } else if (runtime == Runtime.firefox && Platform.isMacOS) {
        skipReason = 'https://github.com/dart-lang/test/pull/2276';
      } else if (compiler == Compiler.cli &&
          sanitizerSuffix != null &&
          !supportsCliCompilerSanitizers) {
        skipReason = 'SDK too old';
      } else if (compiler == Compiler.cli && !supportsCliCompiler) {
        skipReason = 'SDK too old';
      } else if (sanitizerSuffix != null &&
          !File(
            '$sdkDir/bin/'
            '${compiler == Compiler.cli ? 'dartcliruntime' : 'dartaotruntime'}'
            '_$sanitizerSuffix',
          ).existsSync()) {
        skipReason = 'SDK too old';
      }
      group(
        '--runtime ${runtime.identifier} --compiler ${compiler.identifier}',
        skip: skipReason,
        () {
          final testArgs = [
            'test.dart',
            '-p',
            runtime.identifier,
            '-c',
            compiler.identifier,
          ];

          test('can run passing tests', () async {
            await d.file('test.dart', _goodTest).create();
            var test = await runTest(testArgs);

            expect(
              test.stdout,
              emitsThrough(contains('+1: All tests passed!')),
            );
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
              ]),
            );

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
              ]),
            );

            await test.shouldExit(1);
          });

          test('fails gracefully if a test file throws in main', () async {
            await d.file('test.dart', _throwingTest).create();
            var test = await runTest(testArgs);
            expect(
              test.stdout,
              containsInOrder([
                '-1: [${runtime.name}, ${compiler.name}] loading test.dart [E]',
                'Failed to load "test.dart": oh no',
              ]),
            );
            await test.shouldExit(1);
          });

          test('captures prints', () async {
            await d.file('test.dart', _testWithPrints).create();
            var test = await runTest([...testArgs, '-r', 'json']);

            expect(
              test.stdout,
              containsInOrder([
                '"messageType":"print","message":"hello","type":"print"',
              ]),
            );

            await test.shouldExit(0);
          });

          if (runtime.isDartVM) {
            test('forwards stdout/stderr', () async {
              await d.file('test.dart', _testWithStdOutAndErr).create();
              var test = await runTest(testArgs, reporter: 'silent');

              expect(test.stdout, emitsThrough('hello'));
              expect(test.stderr, emits('world'));
              await test.shouldExit(0);
            });
          }

          if (runtime.isDartVM &&
              (compiler == Compiler.exe || compiler == Compiler.cli)) {
            test('can run multiple suites concurrently', () async {
              await d.file('test1.dart', _concurrencyTest(1, 3)).create();
              await d.file('test2.dart', _concurrencyTest(2, 3)).create();
              await d.file('test3.dart', _concurrencyTest(3, 3)).create();
              var test = await runTest([
                'test1.dart',
                'test2.dart',
                'test3.dart',
                '-p',
                runtime.identifier,
                '-c',
                compiler.identifier,
              ], concurrency: 3);

              expect(
                test.stdout,
                emitsThrough(contains('+3: All tests passed!')),
              );
              await test.shouldExit(0);
            });
          }

          if (sanitizerEnvironment != null && compiler == Compiler.cli) {
            test(
              'sets sanitizer environment defaults',
              () async {
                await d
                    .file(
                      'test.dart',
                      _sanitizerEnvironmentTest(
                        sanitizerEnvironment,
                        'halt_on_error=1:exitcode=6:symbolize=1',
                      ),
                    )
                    .create();
                var test = await runTest(testArgs);
                await test.shouldExit(0);
              },
              skip: Platform.environment.containsKey(sanitizerEnvironment)
                  ? '$sanitizerEnvironment is set by the test environment'
                  : null,
            );

            test('preserves sanitizer environment options', () async {
              const options = 'halt_on_error=1:exitcode=7:symbolize=1';
              await d
                  .file(
                    'test.dart',
                    _sanitizerEnvironmentTest(sanitizerEnvironment, options),
                  )
                  .create();
              var test = await runTest(
                testArgs,
                environment: {sanitizerEnvironment: options},
              );
              await test.shouldExit(0);
            });
          }

          test(
            'enables asserts',
            () async {
              await d.file('test.dart', _assertionsEnabledTest).create();
              var test = await runTest(testArgs);

              expect(
                test.stdout,
                emitsThrough(contains('+1: All tests passed!')),
              );
              await test.shouldExit(0);
            },
            skip: compiler == Compiler.cli
                ? 'https://github.com/dart-lang/test/issues/2718'
                : runtime == Runtime.safari
                ? 'https://github.com/dart-lang/test/issues/2720'
                : null,
          );
        },
      );
    }
  }
}

final _goodTest = '''
  import 'package:test/test.dart';

  void main() {
    test("success", () {});
  }
''';

String _concurrencyTest(int id, int total) =>
    '''
  import 'dart:io';
  import 'package:test/test.dart';

  void main() {
    test("concurrent test $id", () async {
      File("test_$id.txt").writeAsStringSync("started");
      final stopwatch = Stopwatch()..start();
      while (![for (var i = 1; i <= $total; i++) File("test_\$i.txt").existsSync()].every((e) => e)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (stopwatch.elapsed > const Duration(seconds: 15)) {
          fail("Timed out waiting for all $total suites to run concurrently");
        }
      }
    });
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

void main() async {
  stdout.writeln('hello');
  await stdout.flush();
  stderr.writeln('world');
  test('success', () {});
}''';

String _sanitizerEnvironmentTest(String name, String value) =>
    '''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('sanitizer environment', () {
    expect(Platform.environment['$name'], '$value');
  });
}
''';

final _assertionsEnabledTest = '''
import 'package:test/test.dart';

void main() {
  test('asserts are enabled', () {
    expect(() {
      assert(false);
    }, throwsA(isA<AssertionError>()));
  });
}
''';
