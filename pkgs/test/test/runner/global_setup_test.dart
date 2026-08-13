// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test(
    'runs global setup once across multiple suites and caches result',
    () async {
      await d.dir('test', [
        d.file('setup.dart', '''
        import 'dart:io';

        Future<String> main() async {
          final file = File('counter.txt');
          final count = file.existsSync() ? int.parse(file.readAsStringSync()) : 0;
          file.writeAsStringSync('\${count + 1}');
          return 'setup_complete';
        }
      '''),
        d.file('test1_test.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        void main() {
          test("test 1", () async {
            final result = await globalSetup<String>(Uri.parse('/test/setup.dart'));
            expect(result, equals('setup_complete'));
            expect(File('counter.txt').readAsStringSync(), equals('1'));
          });
        }
      '''),
        d.file('test2_test.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        void main() {
          test("test 2", () async {
            final result = await globalSetup<String>(Uri.parse('/test/setup.dart'));
            expect(result, equals('setup_complete'));
            expect(File('counter.txt').readAsStringSync(), equals('1'));
          });
        }
      '''),
      ]).create();

      var test = await runTest([
        'test/test1_test.dart',
        'test/test2_test.dart',
      ]);
      expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/counter.txt').readAsStringSync(), equals('1'));
    },
  );

  test('supports Map and JSON-encodable return values', () async {
    await d.dir('test', [
      d.file('config.dart', '''
        Map<String, dynamic> main() {
          return {
            'port': 8080,
            'enabled': true,
            'tags': ['a', 'b'],
          };
        }
      '''),
      d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("receives map from global setup", () async {
            final config = await globalSetup<Map<String, dynamic>>(
              Uri.parse('/test/config.dart'),
            );
            expect(config['port'], equals(8080));
            expect(config['enabled'], isTrue);
            expect(config['tags'], equals(['a', 'b']));
          });
        }
      '''),
    ]).create();

    var test = await runTest(['test/test_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test('runs addGlobalTearDown when test runner closes', () async {
    await d.dir('test', [
      d.file('server.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        Future<String> main() async {
          File('server_started.txt').writeAsStringSync('yes');
          addGlobalTearDown(() async {
            File('server_stopped.txt').writeAsStringSync('yes');
          });
          return 'http://localhost:8080';
        }
      '''),
      d.file('test_test.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        void main() {
          test("uses server", () async {
            final url = await globalSetup<String>(Uri.parse('/test/server.dart'));
            expect(url, equals('http://localhost:8080'));
            expect(File('server_started.txt').existsSync(), isTrue);
            expect(File('server_stopped.txt').existsSync(), isFalse);
          });
        }
      '''),
    ]).create();

    var test = await runTest(['test/test_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);

    expect(File('${d.sandbox}/server_stopped.txt').existsSync(), isTrue);
    expect(
      File('${d.sandbox}/server_stopped.txt').readAsStringSync(),
      equals('yes'),
    );
  });

  test('fails the test if global setup throws an exception', () async {
    await d.dir('test', [
      d.file('fail.dart', '''
        void main() {
          throw Exception('Database connection refused');
        }
      '''),
      d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test that needs failing setup", () async {
            await globalSetup(Uri.parse('/test/fail.dart'));
          });
        }
      '''),
    ]).create();

    var test = await runTest(['test/test_test.dart']);
    expect(test.stdout, emitsThrough(contains('Database connection refused')));
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('fails the test if global setup has compilation error', () async {
    await d.dir('test', [
      d.file('bad.dart', '''
        void main() {
          invalid syntax ;;;
        }
      '''),
      d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test with bad setup", () async {
            await globalSetup(Uri.parse('/test/bad.dart'));
          });
        }
      '''),
    ]).create();

    var test = await runTest(['test/test_test.dart']);
    expect(test.stdout, emitsThrough(contains('failed to compile')));
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('supports root-relative paths', () async {
    await d.dir('test', [
      d.file('setup.dart', '''
        String main() => 'root_relative_ok';
      '''),
      d.dir('sub', [
        d.file('nested_test.dart', '''
          import 'package:test/test.dart';

          void main() {
            test("root relative global setup", () async {
              final result = await globalSetup<String>(
                Uri.parse('/test/setup.dart'),
              );
              expect(result, equals('root_relative_ok'));
            });
          }
        '''),
      ]),
    ]).create();

    var test = await runTest(['test/sub/nested_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test(
    'relative and root-relative paths in nested tests share the same global setup cache',
    () async {
      await d.dir('test', [
        d.file('counter.dart', '''
        import 'dart:io';

        int main() {
          final file = File('counter.txt');
          final count = file.existsSync() ? int.parse(file.readAsStringSync()) : 0;
          file.writeAsStringSync('\${count + 1}');
          return count + 1;
        }
      '''),
        d.dir('sub', [
          d.file('sub_test.dart', '''
            import 'dart:io';
            import 'package:test/test.dart';

            void main() {
              test("relative path setup", () async {
                final result = await globalSetup<int>(
                  Uri.parse('../counter.dart'),
                );
                expect(result, equals(1));
              });
            }
          '''),
        ]),
        d.file('top_test.dart', '''
          import 'dart:io';
          import 'package:test/test.dart';

          void main() {
            test("root relative setup", () async {
              final result = await globalSetup<int>(
                Uri.parse('/test/counter.dart'),
              );
              expect(result, equals(1));
            });
          }
        '''),
      ]).create();

      var test = await runTest([
        'test/sub/sub_test.dart',
        'test/top_test.dart',
      ]);
      expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/counter.txt').readAsStringSync(), equals('1'));
    },
  );

  test('supports absolute file: URIs', () async {
    await d.dir('test', [
      d.file('setup.dart', '''
        String main() => 'file_uri_ok';
      '''),
      d.file('test_test.dart', '''
        import 'dart:io';
        import 'package:path/path.dart' as p;
        import 'package:test/test.dart';

        void main() {
          test("absolute file URI setup", () async {
            final absoluteUri = Uri.file(p.absolute('test/setup.dart'));
            final result = await globalSetup<String>(absoluteUri);
            expect(result, equals('file_uri_ok'));
          });
        }
      '''),
    ]).create();

    var test = await runTest(['test/test_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test(
    'runs multiple addGlobalTearDown callbacks in reverse (LIFO) order',
    () async {
      await d.dir('test', [
        d.file('lifo.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        String main() {
          addGlobalTearDown(() async {
            File('log.txt').writeAsStringSync('first\\n', mode: FileMode.append);
          });
          addGlobalTearDown(() async {
            File('log.txt').writeAsStringSync('second\\n', mode: FileMode.append);
          });
          return 'ok';
        }
      '''),
        d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("lifo teardown test", () async {
            final result = await globalSetup<String>(Uri.parse('/test/lifo.dart'));
            expect(result, equals('ok'));
          });
        }
      '''),
      ]).create();

      var test = await runTest(['test/test_test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      expect(
        File('${d.sandbox}/log.txt').readAsStringSync(),
        equals('second\nfirst\n'),
      );
    },
  );

  test(
    'supports multiple distinct global setup scripts in the same run',
    () async {
      await d.dir('test', [
        d.file('setup_a.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        String main() {
          File('started_a.txt').writeAsStringSync('yes');
          addGlobalTearDown(() async {
            File('stopped_a.txt').writeAsStringSync('yes');
          });
          return 'service_a';
        }
      '''),
        d.file('setup_b.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        String main() {
          File('started_b.txt').writeAsStringSync('yes');
          addGlobalTearDown(() async {
            File('stopped_b.txt').writeAsStringSync('yes');
          });
          return 'service_b';
        }
      '''),
        d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("uses multiple services", () async {
            final a = await globalSetup<String>(Uri.parse('/test/setup_a.dart'));
            final b = await globalSetup<String>(Uri.parse('/test/setup_b.dart'));
            expect(a, equals('service_a'));
            expect(b, equals('service_b'));
          });
        }
      '''),
      ]).create();

      var test = await runTest(['test/test_test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/started_a.txt').existsSync(), isTrue);
      expect(File('${d.sandbox}/started_b.txt').existsSync(), isTrue);
      expect(File('${d.sandbox}/stopped_a.txt').existsSync(), isTrue);
      expect(File('${d.sandbox}/stopped_b.txt').existsSync(), isTrue);
    },
  );

  test('fails the test run if a global teardown callback throws', () async {
    await d.dir('test', [
      d.file('failing_teardown.dart', '''
        import 'package:test/test.dart';

        String main() {
          addGlobalTearDown(() async {
            throw Exception('Cleanup failed: resource locked');
          });
          return 'ready';
        }
      '''),
      d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("runs successfully during test phase", () async {
            final result = await globalSetup<String>(
              Uri.parse('/test/failing_teardown.dart'),
            );
            expect(result, equals('ready'));
          });
        }
      '''),
    ]).create();

    var test = await runTest(['test/test_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    expect(
      test.stderr,
      emitsThrough(contains('Cleanup failed: resource locked')),
    );
    await test.shouldExit(1);
  });

  test(
    'handles concurrent globalSetup calls without race conditions',
    () async {
      await d.dir('test', [
        d.file('slow_setup.dart', '''
        import 'dart:io';

        Future<int> main() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final file = File('counter.txt');
          final count = file.existsSync() ? int.parse(file.readAsStringSync()) : 0;
          file.writeAsStringSync('\${count + 1}');
          return count + 1;
        }
      '''),
        d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("concurrent call 1", () async {
            final result = await globalSetup<int>(Uri.parse('/test/slow_setup.dart'));
            expect(result, equals(1));
          });

          test("concurrent call 2", () async {
            final result = await globalSetup<int>(Uri.parse('/test/slow_setup.dart'));
            expect(result, equals(1));
          });

          test("concurrent call 3", () async {
            final result = await globalSetup<int>(Uri.parse('/test/slow_setup.dart'));
            expect(result, equals(1));
          });
        }
      '''),
      ]).create();

      var test = await runTest(['test/test_test.dart'], concurrency: 3);
      expect(test.stdout, emitsThrough(contains('+3: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/counter.txt').readAsStringSync(), equals('1'));
    },
  );

  test(
    'throws UnsupportedError if addGlobalTearDown is called outside globalSetup',
    () async {
      await d.dir('test', [
        d.file('test_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("misuse of addGlobalTearDown", () {
            expect(
              () => addGlobalTearDown(() {}),
              throwsA(isA<UnsupportedError>()),
            );
          });
        }
      '''),
      ]).create();

      var test = await runTest(['test/test_test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    },
  );

  test(
    'supports running tests directly via dart command outside dart test',
    () async {
      await d.dir('test', [
        d.file('setup.dart', '''
        import 'dart:io';
        import 'package:test/test.dart';

        String main() {
          addGlobalTearDown(() async {
            File('direct_stopped.txt').writeAsStringSync('yes');
          });
          return 'standalone_ok';
        }
      '''),
        d.file('direct_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("direct run", () async {
            final result = await globalSetup<String>(Uri.parse('/test/setup.dart'));
            expect(result, equals('standalone_ok'));
          });
        }
      '''),
      ]).create();

      var test = await runDart(['test/direct_test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/direct_stopped.txt').existsSync(), isTrue);
    },
  );
}
