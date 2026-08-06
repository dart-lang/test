// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test('runs pre_run hook when matching tagged suite is executed', () async {
    await d
        .file(
          'dart_test.yaml',
          jsonEncode({
            'tags': {
              'needs_setup': {
                'pre_run': {
                  'command': Platform.resolvedExecutable,
                  'args': ['tool/setup.dart'],
                },
              },
            },
          }),
        )
        .create();

    await d.dir('tool', [
      d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          File('setup_done.txt').writeAsStringSync('ready');
        }
      '''),
    ]).create();

    await d.file('test.dart', '''
      @Tags(['needs_setup'])
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test", () {
          expect(File('setup_done.txt').existsSync(), isTrue);
          expect(File('setup_done.txt').readAsStringSync(), equals('ready'));
        });
      }
    ''').create();

    var test = await runTest(['test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test(
    'does not run pre_run hook when no matching tagged suite is run',
    () async {
      await d
          .file(
            'dart_test.yaml',
            jsonEncode({
              'tags': {
                'needs_setup': {
                  'pre_run': {
                    'command': Platform.resolvedExecutable,
                    'args': ['tool/setup.dart'],
                  },
                },
              },
            }),
          )
          .create();

      await d.dir('tool', [
        d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          File('setup_done.txt').writeAsStringSync('ready');
        }
      '''),
      ]).create();

      await d.file('test.dart', '''
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test", () {
          expect(File('setup_done.txt').existsSync(), isFalse);
        });
      }
    ''').create();

      var test = await runTest(['test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    },
  );

  test('runs pre_run hook only once across multiple matching suites', () async {
    await d
        .file(
          'dart_test.yaml',
          jsonEncode({
            'tags': {
              'needs_setup': {
                'pre_run': {
                  'command': Platform.resolvedExecutable,
                  'args': ['tool/setup.dart'],
                },
              },
            },
          }),
        )
        .create();

    await d.dir('tool', [
      d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          final file = File('counter.txt');
          int count = 0;
          if (file.existsSync()) {
            count = int.parse(file.readAsStringSync());
          }
          file.writeAsStringSync('\${count + 1}');
        }
      '''),
    ]).create();

    await d.file('test1_test.dart', '''
      @Tags(['needs_setup'])
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test 1", () {
          expect(File('counter.txt').readAsStringSync(), equals('1'));
        });
      }
    ''').create();

    await d.file('test2_test.dart', '''
      @Tags(['needs_setup'])
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test 2", () {
          expect(File('counter.txt').readAsStringSync(), equals('1'));
        });
      }
    ''').create();

    var test = await runTest(['test1_test.dart', 'test2_test.dart']);
    expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
    await test.shouldExit(0);
  });

  test('aborts test run if pre_run hook fails', () async {
    await d
        .file(
          'dart_test.yaml',
          jsonEncode({
            'tags': {
              'failing_setup': {
                'pre_run': {
                  'command': Platform.resolvedExecutable,
                  'args': ['tool/fail.dart'],
                },
              },
            },
          }),
        )
        .create();

    await d.dir('tool', [
      d.file('fail.dart', '''
        import 'dart:io';

        void main() {
          stderr.writeln('Setup crashed');
          exit(1);
        }
      '''),
    ]).create();

    await d.file('test.dart', '''
      @Tags(['failing_setup'])
      import 'package:test/test.dart';

      void main() {
        test("test", () {});
      }
    ''').create();

    var test = await runTest(['test.dart']);
    expect(test.stderr, emitsThrough(contains('Pre-run hook')));
    await test.shouldExit(65);
  });

  test('runs post_run teardown hook after tests complete', () async {
    await d
        .file(
          'dart_test.yaml',
          jsonEncode({
            'tags': {
              'with_teardown': {
                'pre_run': {
                  'command': Platform.resolvedExecutable,
                  'args': ['tool/setup.dart'],
                },
                'post_run': {
                  'command': Platform.resolvedExecutable,
                  'args': ['tool/teardown.dart'],
                },
              },
            },
          }),
        )
        .create();

    await d.dir('tool', [
      d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          File('status.txt').writeAsStringSync('started');
        }
      '''),
      d.file('teardown.dart', '''
        import 'dart:io';

        void main() {
          File('status.txt').writeAsStringSync('cleaned_up');
        }
      '''),
    ]).create();

    await d.file('test.dart', '''
      @Tags(['with_teardown'])
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test", () {
          expect(File('status.txt').readAsStringSync(), equals('started'));
        });
      }
    ''').create();

    var test = await runTest(['test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);

    expect(
      File('${d.sandbox}/status.txt').readAsStringSync(),
      equals('cleaned_up'),
    );
  });

  test('runs standalone post_run hook after tests complete', () async {
    await d
        .file(
          'dart_test.yaml',
          jsonEncode({
            'tags': {
              'cleanup_only': {
                'post_run': {
                  'command': Platform.resolvedExecutable,
                  'args': ['tool/teardown.dart'],
                },
              },
            },
          }),
        )
        .create();

    await d.dir('tool', [
      d.file('teardown.dart', '''
        import 'dart:io';

        void main() {
          File('cleaned.txt').writeAsStringSync('done');
        }
      '''),
    ]).create();

    await d.file('test.dart', '''
      @Tags(['cleanup_only'])
      import 'package:test/test.dart';

      void main() {
        test("test", () {});
      }
    ''').create();

    var test = await runTest(['test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);

    expect(File('${d.sandbox}/cleaned.txt').existsSync(), isTrue);
  });

  test('supports list format for pre_run and post_run', () async {
    await d
        .file(
          'dart_test.yaml',
          jsonEncode({
            'tags': {
              'list_format': {
                'pre_run': [Platform.resolvedExecutable, 'tool/setup.dart'],
                'post_run': [Platform.resolvedExecutable, 'tool/teardown.dart'],
              },
            },
          }),
        )
        .create();

    await d.dir('tool', [
      d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          File('list_done.txt').writeAsStringSync('ready');
        }
      '''),
      d.file('teardown.dart', '''
        import 'dart:io';

        void main() {
          File('list_done.txt').writeAsStringSync('cleaned');
        }
      '''),
    ]).create();

    await d.file('test.dart', '''
      @Tags(['list_format'])
      import 'dart:io';
      import 'package:test/test.dart';

      void main() {
        test("test", () {
          expect(File('list_done.txt').readAsStringSync(), equals('ready'));
        });
      }
    ''').create();

    var test = await runTest(['test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);

    expect(
      File('${d.sandbox}/list_done.txt').readAsStringSync(),
      equals('cleaned'),
    );
  });

  test(
    'does not run pre_run or post_run when matching tag is excluded via CLI',
    () async {
      await d
          .file(
            'dart_test.yaml',
            jsonEncode({
              'tags': {
                'excluded_tag': {
                  'pre_run': {
                    'command': Platform.resolvedExecutable,
                    'args': ['tool/setup.dart'],
                  },
                  'post_run': {
                    'command': Platform.resolvedExecutable,
                    'args': ['tool/teardown.dart'],
                  },
                },
              },
            }),
          )
          .create();

      await d.dir('tool', [
        d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          File('pre_ran.txt').writeAsStringSync('ran');
        }
      '''),
        d.file('teardown.dart', '''
        import 'dart:io';

        void main() {
          File('post_ran.txt').writeAsStringSync('ran');
        }
      '''),
      ]).create();

      await d.file('test1_test.dart', '''
      @Tags(['excluded_tag'])
      import 'package:test/test.dart';

      void main() {
        test("test 1", () {});
      }
    ''').create();

      await d.file('test2_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 2", () {});
      }
    ''').create();

      var test = await runTest([
        '--exclude-tag',
        'excluded_tag',
        'test1_test.dart',
        'test2_test.dart',
      ]);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      expect(File('${d.sandbox}/pre_ran.txt').existsSync(), isFalse);
      expect(File('${d.sandbox}/post_ran.txt').existsSync(), isFalse);
    },
  );

  test(
    'provides DART_TEST_SESSION_DIR to pre_run and post_run and cleans up',
    () async {
      await d
          .file(
            'dart_test.yaml',
            jsonEncode({
              'tags': {
                'session_test': {
                  'pre_run': {
                    'command': Platform.resolvedExecutable,
                    'args': ['tool/setup.dart'],
                  },
                  'post_run': {
                    'command': Platform.resolvedExecutable,
                    'args': ['tool/teardown.dart'],
                  },
                },
              },
            }),
          )
          .create();

      await d.dir('tool', [
        d.file('setup.dart', '''
        import 'dart:io';

        void main() {
          final sessionDir = Platform.environment['DART_TEST_SESSION_DIR']!;
          File('\$sessionDir/snapshot.txt').writeAsStringSync('compiled_pub');
        }
      '''),
        d.file('teardown.dart', '''
        import 'dart:io';

        void main() {
          final sessionDir = Platform.environment['DART_TEST_SESSION_DIR']!;
          if (File('\$sessionDir/snapshot.txt').existsSync()) {
            File('post_saw_snapshot.txt').writeAsStringSync('yes');
          }
        }
      '''),
      ]).create();

      await d.file('test.dart', '''
      @Tags(['session_test'])
      import 'dart:io';
      import 'package:path/path.dart' as p;
      import 'package:test/test.dart';

      void main() {
        test("reads session artifact via testSessionPath", () {
          final snapshot = File(p.join(testSessionPath, 'snapshot.txt'));
          expect(snapshot.existsSync(), isTrue);
          expect(snapshot.readAsStringSync(), equals('compiled_pub'));
        });
      }
    ''').create();

      var test = await runTest(['test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      expect(
        File('${d.sandbox}/post_saw_snapshot.txt').readAsStringSync(),
        equals('yes'),
      );
      final sessionsDir = Directory('${d.sandbox}/.dart_tool/test/sessions');
      if (sessionsDir.existsSync()) {
        expect(sessionsDir.listSync().isEmpty, isTrue);
      }
    },
  );

  test(
    'cleans up stale unlocked sessions from previous runs on startup',
    () async {
      await d.dir('.dart_tool', [
        d.dir('test', [
          d.dir('sessions', [
            d.dir('99999', [
              d.file('session.lock', ''),
              d.file('stale.txt', 'abandoned'),
            ]),
          ]),
        ]),
      ]).create();

      await d.file('test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("dummy", () {});
      }
    ''').create();

      var test = await runTest(['test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);

      expect(
        Directory('${d.sandbox}/.dart_tool/test/sessions/99999').existsSync(),
        isFalse,
      );
    },
  );
}
