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
      await d.dir('tool', [
        d.file('setup.dart', '''
        import 'dart:io';

        Future<String> main() async {
          final file = File('counter.txt');
          final count = file.existsSync() ? int.parse(file.readAsStringSync()) : 0;
          file.writeAsStringSync('\${count + 1}');
          return 'setup_complete';
        }
      '''),
      ]).create();

      await d.file('test1_test.dart', '''
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test 1", () async {
          final result = await globalSetup<String>('tool/setup.dart');
          expect(result, equals('setup_complete'));
          expect(File('counter.txt').readAsStringSync(), equals('1'));
        });
      }
    ''').create();

      await d.file('test2_test.dart', '''
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test 2", () async {
          final result = await globalSetup<String>('tool/setup.dart');
          expect(result, equals('setup_complete'));
          expect(File('counter.txt').readAsStringSync(), equals('1'));
        });
      }
    ''').create();

      var test = await runTest(['test1_test.dart', 'test2_test.dart']);
      expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/counter.txt').readAsStringSync(), equals('1'));
    },
  );

  test('supports Map and JSON-encodable return values', () async {
    await d.dir('tool', [
      d.file('config.dart', '''
        Map<String, dynamic> main() {
          return {
            'port': 8080,
            'enabled': true,
            'tags': ['a', 'b'],
          };
        }
      '''),
    ]).create();

    await d.file('test_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("receives map from global setup", () async {
          final config = await globalSetup<Map<String, dynamic>>('tool/config.dart');
          expect(config['port'], equals(8080));
          expect(config['enabled'], isTrue);
          expect(config['tags'], equals(['a', 'b']));
        });
      }
    ''').create();

    var test = await runTest(['test_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test('runs addGlobalTearDown when test runner closes', () async {
    await d.dir('tool', [
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
    ]).create();

    await d.file('test_test.dart', '''
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("uses server", () async {
          final url = await globalSetup<String>('tool/server.dart');
          expect(url, equals('http://localhost:8080'));
          expect(File('server_started.txt').existsSync(), isTrue);
          expect(File('server_stopped.txt').existsSync(), isFalse);
        });
      }
    ''').create();

    var test = await runTest(['test_test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);

    expect(File('${d.sandbox}/server_stopped.txt').existsSync(), isTrue);
    expect(
      File('${d.sandbox}/server_stopped.txt').readAsStringSync(),
      equals('yes'),
    );
  });

  test('fails the test if global setup throws an exception', () async {
    await d.dir('tool', [
      d.file('fail.dart', '''
        void main() {
          throw Exception('Database connection refused');
        }
      '''),
    ]).create();

    await d.file('test_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test that needs failing setup", () async {
          await globalSetup('tool/fail.dart');
        });
      }
    ''').create();

    var test = await runTest(['test_test.dart']);
    expect(test.stdout, emitsThrough(contains('Database connection refused')));
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('fails the test if global setup has compilation error', () async {
    await d.dir('tool', [
      d.file('bad.dart', '''
        void main() {
          invalid syntax ;;;
        }
      '''),
    ]).create();

    await d.file('test_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test with bad setup", () async {
          await globalSetup('tool/bad.dart');
        });
      }
    ''').create();

    var test = await runTest(['test_test.dart']);
    expect(test.stdout, emitsThrough(contains('failed to compile')));
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('supports root-relative paths', () async {
    await d.dir('tool', [
      d.file('setup.dart', '''
        String main() => 'root_relative_ok';
      '''),
    ]).create();

    await d.dir('test', [
      d.dir('sub', [
        d.file('nested_test.dart', '''
          import 'package:test/test.dart';

          void main() {
            test("root relative global setup", () async {
              final result = await globalSetup<String>('/tool/setup.dart');
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
      await d.dir('tool', [
        d.file('counter.dart', '''
        import 'dart:io';

        int main() {
          final file = File('counter.txt');
          final count = file.existsSync() ? int.parse(file.readAsStringSync()) : 0;
          file.writeAsStringSync('\${count + 1}');
          return count + 1;
        }
      '''),
      ]).create();

      await d.dir('test', [
        d.dir('sub', [
          d.file('sub_test.dart', '''
            import 'dart:io';
            import 'package:test/test.dart';

            void main() {
              test("relative path setup", () async {
                final result = await globalSetup<int>('../../tool/counter.dart');
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
              final result = await globalSetup<int>('/tool/counter.dart');
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
}
