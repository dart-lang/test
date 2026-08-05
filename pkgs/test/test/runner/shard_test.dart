// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:test_core/src/util/exit_codes.dart' as exit_codes;
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  test('divides all the tests among the available shards', () async {
    await d.file('test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 1", () {});
        test("test 2", () {});
        test("test 3", () {});
        test("test 4", () {});
        test("test 5", () {});
        test("test 6", () {});
        test("test 7", () {});
        test("test 8", () {});
        test("test 9", () {});
        test("test 10", () {});
      }
    ''').create();

    var test = await runTest([
      'test.dart',
      '--shard-index=0',
      '--total-shards=3',
    ]);
    expect(
      test.stdout,
      containsInOrder([
        '+0: test 1',
        '+1: test 2',
        '+2: test 3',
        '+3: All tests passed!',
      ]),
    );
    await test.shouldExit(0);

    test = await runTest(['test.dart', '--shard-index=1', '--total-shards=3']);
    expect(
      test.stdout,
      containsInOrder([
        '+0: test 4',
        '+1: test 5',
        '+2: test 6',
        '+3: test 7',
        '+4: All tests passed!',
      ]),
    );
    await test.shouldExit(0);

    test = await runTest(['test.dart', '--shard-index=2', '--total-shards=3']);
    expect(
      test.stdout,
      containsInOrder([
        '+0: test 8',
        '+1: test 9',
        '+2: test 10',
        '+3: All tests passed!',
      ]),
    );
    await test.shouldExit(0);
  });

  test('shards each suite', () async {
    await d.file('1_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 1.1", () {});
        test("test 1.2", () {});
        test("test 1.3", () {});
      }
    ''').create();

    await d.file('2_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 2.1", () {});
        test("test 2.2", () {});
        test("test 2.3", () {});
      }
    ''').create();

    var test = await runTest(['.', '--shard-index=0', '--total-shards=3']);
    expect(
      test.stdout,
      emitsInOrder([
        emitsAnyOf([
          containsInOrder([
            '+0: ./1_test.dart: test 1.1',
            '+1: ./2_test.dart: test 2.1',
          ]),
          containsInOrder([
            '+0: ./2_test.dart: test 2.1',
            '+1: ./1_test.dart: test 1.1',
          ]),
        ]),
        contains('+2: All tests passed!'),
      ]),
    );
    await test.shouldExit(0);

    test = await runTest(['.', '--shard-index=1', '--total-shards=3']);
    expect(
      test.stdout,
      emitsInOrder([
        emitsAnyOf([
          containsInOrder([
            '+0: ./1_test.dart: test 1.2',
            '+1: ./2_test.dart: test 2.2',
          ]),
          containsInOrder([
            '+0: ./2_test.dart: test 2.2',
            '+1: ./1_test.dart: test 1.2',
          ]),
        ]),
        contains('+2: All tests passed!'),
      ]),
    );
    await test.shouldExit(0);

    test = await runTest(['.', '--shard-index=2', '--total-shards=3']);
    expect(
      test.stdout,
      emitsInOrder([
        emitsAnyOf([
          containsInOrder([
            '+0: ./1_test.dart: test 1.3',
            '+1: ./2_test.dart: test 2.3',
          ]),
          containsInOrder([
            '+0: ./2_test.dart: test 2.3',
            '+1: ./1_test.dart: test 1.3',
          ]),
        ]),
        contains('+2: All tests passed!'),
      ]),
    );
    await test.shouldExit(0);
  });

  test('an empty shard reports success', () async {
    await d.file('test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 1", () {});
        test("test 2", () {});
      }
    ''').create();

    var test = await runTest([
      'test.dart',
      '--shard-index=1',
      '--total-shards=3',
    ]);
    expect(test.stdout, emitsThrough('No tests ran.'));
    await test.shouldExit(79);
  });

  test('shards by suite', () async {
    await d.file('1_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 1.1", () {});
        test("test 1.2", () {});
      }
    ''').create();

    await d.file('2_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("test 2.1", () {});
        test("test 2.2", () {});
      }
    ''').create();

    var test = await runTest([
      '.',
      '--shard-index=0',
      '--total-shards=2',
      '--shard-by-suite',
    ]);
    expect(
      test.stdout,
      containsInOrder([
        '+0: ./1_test.dart: test 1.1',
        '+1: ./1_test.dart: test 1.2',
        '+2: All tests passed!',
      ]),
    );
    expect(test.stdout, isNot(contains('./2_test.dart')));
    await test.shouldExit(0);

    test = await runTest([
      '.',
      '--shard-index=1',
      '--total-shards=2',
      '--shard-by-suite',
    ]);
    expect(
      test.stdout,
      containsInOrder([
        '+0: ./2_test.dart: test 2.1',
        '+1: ./2_test.dart: test 2.2',
        '+2: All tests passed!',
      ]),
    );
    expect(test.stdout, isNot(contains('./1_test.dart')));
    await test.shouldExit(0);
  });

  test('round-robin interleaves suites across shards', () async {
    await d.file('1_test.dart', '''
      import 'package:test/test.dart';
      void main() { test("test 1", () {}); }
    ''').create();

    await d.file('2_test.dart', '''
      import 'package:test/test.dart';
      void main() { test("test 2", () {}); }
    ''').create();

    await d.file('3_test.dart', '''
      import 'package:test/test.dart';
      void main() { test("test 3", () {}); }
    ''').create();

    await d.file('4_test.dart', '''
      import 'package:test/test.dart';
      void main() { test("test 4", () {}); }
    ''').create();

    // Shard 0 gets index 0 (1_test) and index 2 (3_test)
    var test = await runTest([
      '.',
      '--shard-index=0',
      '--total-shards=2',
      '--shard-by-suite',
    ]);
    expect(
      test.stdout,
      containsInOrder([
        '+0: ./1_test.dart: test 1',
        '+1: ./3_test.dart: test 3',
        '+2: All tests passed!',
      ]),
    );
    expect(test.stdout, isNot(contains('./2_test.dart')));
    expect(test.stdout, isNot(contains('./4_test.dart')));
    await test.shouldExit(0);

    // Shard 1 gets index 1 (2_test) and index 3 (4_test)
    test = await runTest([
      '.',
      '--shard-index=1',
      '--total-shards=2',
      '--shard-by-suite',
    ]);
    expect(
      test.stdout,
      containsInOrder([
        '+0: ./2_test.dart: test 2',
        '+1: ./4_test.dart: test 4',
        '+2: All tests passed!',
      ]),
    );
    expect(test.stdout, isNot(contains('./1_test.dart')));
    expect(test.stdout, isNot(contains('./3_test.dart')));
    await test.shouldExit(0);
  });

  test('interaction of --shard-by-suite with name filters', () async {
    await d.file('1_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("match", () {});
      }
    ''').create();

    await d.file('2_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("other", () {});
      }
    ''').create();

    var test = await runTest([
      '.',
      '--shard-index=1',
      '--total-shards=2',
      '--shard-by-suite',
      '--name=match',
    ]);
    expect(test.stdout, emitsThrough('No tests ran.'));
    await test.shouldExit(79);

    test = await runTest([
      '.',
      '--shard-index=0',
      '--total-shards=2',
      '--shard-by-suite',
      '--name=match',
    ]);
    expect(
      test.stdout,
      containsInOrder(['+0: ./1_test.dart: match', '+1: All tests passed!']),
    );
    await test.shouldExit(0);
  });

  test('interaction of --shard-by-suite with suite-level tag filters', () async {
    await d.file('1_test.dart', '''
      @Tags(['match'])
      import 'package:test/test.dart';

      void main() {
        test("match", () {});
      }
    ''').create();

    await d.file('2_test.dart', '''
      @Tags(['other'])
      import 'package:test/test.dart';

      void main() {
        test("other", () {});
      }
    ''').create();

    // 2_test.dart is filtered out before sharding. Only 1_test.dart is sharded.
    // Shard 0 gets 1_test.dart.
    var test = await runTest([
      '.',
      '--shard-index=0',
      '--total-shards=2',
      '--shard-by-suite',
      '--tags=match',
    ]);
    expect(
      test.stdout,
      containsInOrder(['+0: ./1_test.dart: match', '+1: All tests passed!']),
    );
    await test.shouldExit(0);

    // Shard 1 gets no files since only 1 file matched pre-sharding filter.
    test = await runTest([
      '.',
      '--shard-index=1',
      '--total-shards=2',
      '--shard-by-suite',
      '--tags=match',
    ]);
    expect(test.stdout, emitsThrough('No tests ran.'));
    await test.shouldExit(79);
  });

  test('interaction of --shard-by-suite with test-level tag filters', () async {
    await d.file('1_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("match", tags: "match", () {});
      }
    ''').create();

    await d.file('2_test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("other", tags: "other", () {});
      }
    ''').create();

    // Test-level tags are evaluated within loaded suites after sharding.
    // Shard 1 gets 2_test.dart, which has no matching tests.
    var test = await runTest([
      '.',
      '--shard-index=1',
      '--total-shards=2',
      '--shard-by-suite',
      '--tags=match',
    ]);
    expect(test.stdout, emitsThrough('No tests ran.'));
    await test.shouldExit(79);

    // Shard 0 gets 1_test.dart, which runs.
    test = await runTest([
      '.',
      '--shard-index=0',
      '--total-shards=2',
      '--shard-by-suite',
      '--tags=match',
    ]);
    expect(
      test.stdout,
      containsInOrder(['+0: ./1_test.dart: match', '+1: All tests passed!']),
    );
    await test.shouldExit(0);
  });

  test('interaction of default sharding with name filters', () async {
    await d.file('test.dart', '''
      import 'package:test/test.dart';

      void main() {
        test("match 1", () {});
        test("match 2", () {});
        test("other 1", () {});
        test("other 2", () {});
      }
    ''').create();

    var test = await runTest([
      'test.dart',
      '--shard-index=0',
      '--total-shards=2',
      '--name=match',
    ]);
    expect(
      test.stdout,
      containsInOrder(['+0: match 1', '+1: All tests passed!']),
    );
    expect(test.stdout, isNot(contains('match 2')));
    await test.shouldExit(0);

    test = await runTest([
      'test.dart',
      '--shard-index=1',
      '--total-shards=2',
      '--name=match',
    ]);
    expect(
      test.stdout,
      containsInOrder(['+0: match 2', '+1: All tests passed!']),
    );
    expect(test.stdout, isNot(contains('match 1')));
    await test.shouldExit(0);
  });

  group('errors:', () {
    test('--shard-index is provided alone', () async {
      var test = await runTest(['--shard-index=1']);
      expect(
        test.stderr,
        emits('--shard-index and --total-shards may only be passed together.'),
      );
      await test.shouldExit(exit_codes.usage);
    });

    test('--total-shards is provided alone', () async {
      var test = await runTest(['--total-shards=5']);
      expect(
        test.stderr,
        emits('--shard-index and --total-shards may only be passed together.'),
      );
      await test.shouldExit(exit_codes.usage);
    });

    test('--shard-index is negative', () async {
      var test = await runTest(['--shard-index=-1', '--total-shards=5']);
      expect(test.stderr, emits('--shard-index may not be negative.'));
      await test.shouldExit(exit_codes.usage);
    });

    test('--shard-index is too large', () async {
      var test = await runTest(['--shard-index=5', '--total-shards=5']);
      expect(
        test.stderr,
        emits('--shard-index must be less than --total-shards.'),
      );
      await test.shouldExit(exit_codes.usage);
    });
  });

  group('--shard-by-suite edge cases:', () {
    test('less test suites than shards', () async {
      await d.file('1_test.dart', '''
        import 'package:test/test.dart';
        void main() {
          test("test 1", () {});
        }
      ''').create();

      var test = await runTest([
        '.',
        '--shard-index=0',
        '--total-shards=2',
        '--shard-by-suite',
      ]);
      expect(test.stdout, emitsThrough(contains('+0: ./1_test.dart: test 1')));
      await test.shouldExit(0);

      test = await runTest([
        '.',
        '--shard-index=1',
        '--total-shards=2',
        '--shard-by-suite',
      ]);
      expect(test.stdout, emitsThrough('No tests ran.'));
      await test.shouldExit(79);
    });

    test('no test suites found', () async {
      var test = await runTest([
        '.',
        '--shard-index=0',
        '--total-shards=2',
        '--shard-by-suite',
      ]);
      expect(test.stderr, emitsThrough('No tests were found.'));
      await test.shouldExit(exit_codes.noTestsRan);
    });

    group('interaction with @TestOn:', () {
      test('sharding by suite respects @TestOn before sharding', () async {
        await d.file('vm_test.dart', '''
          @TestOn('vm')
          import 'package:test/test.dart';
          void main() {
            test("vm", () {});
          }
        ''').create();

        await d.file('browser_test.dart', '''
          @TestOn('browser')
          import 'package:test/test.dart';
          void main() {
            test("browser", () {});
          }
        ''').create();

        // browser_test.dart is filtered out before sharding when running on VM.
        // So only vm_test.dart is sharded. Shard 0 gets vm_test.dart.
        var test = await runTest([
          '.',
          '--shard-index=0',
          '--total-shards=2',
          '--shard-by-suite',
        ]);
        expect(test.stdout, emitsThrough(contains('+0: ./vm_test.dart: vm')));
        await test.shouldExit(0);

        // Shard 1 gets no files.
        test = await runTest([
          '.',
          '--shard-index=1',
          '--total-shards=2',
          '--shard-by-suite',
        ]);
        expect(test.stdout, emitsThrough('No tests ran.'));
        await test.shouldExit(79);
      });
    });
  });
}
