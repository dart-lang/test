// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
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

  group('with test.dart?line=<line> query', () {
    test('selects test with the matching line', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
          test("b", () => throw TestFailure("oh no"));
          test("c", () {});
        }
      ''').create();

      var test = await runTest(['test.dart?line=6']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('selects multiple tests on the same line', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {}); test("b", () {});
          test("c", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?line=4']);

      expect(
        test.stdout,
        emitsThrough(contains('+2: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('additionally selects test with matching custom location', () async {
      await d.dir('test').create();
      var testFileUri = Uri.file(d.file('test/aaa_test.dart').io.path);
      var notTestFileUri = Uri.file(d.file('test/bbb.dart').io.path);
      var testFilePackageRelativeUri =
          Uri.parse('org-dartlang-app:///test/aaa_test.dart');
      await d.file('test/aaa_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {}); // Line 4 from stack trace (match)

          // Custom line 4 (match)
          test("b", location: TestLocation(Uri.parse('$testFileUri'), 4, 0), () {});

          // Custom line 4 match but using org-dartlang-app (match)
          test("c", location: TestLocation(Uri.parse('$testFilePackageRelativeUri'), 4, 0), () {});

          // Custom different line, same file (no match)
          test("d", location: TestLocation(Uri.parse('$testFileUri'), 5, 0), () => throw TestFailure("oh no"));

          // Custom line 4 match but different file (no match)
          test("e", location: TestLocation(Uri.parse('$notTestFileUri'), 4, 0), () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test/aaa_test.dart?line=4']);

      expect(
        test.stdout,
        emitsThrough(contains('+3: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('selects groups with a matching line', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          group("a", () {
            test("a", () {});
          });
          group("b", () {
            test("b", () => throw TestFailure("oh no"));
          });
        }
      ''').create();

      var test = await runTest(['test.dart?line=4']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('additionally selects groups with a matching custom location',
        () async {
      await d.dir('test').create();
      var testFileUri = Uri.file(d.file('test/aaa_test.dart').io.path);
      var notTestFileUri = Uri.file(d.file('test/bbb.dart').io.path);
      var testFilePackageRelativeUri =
          Uri.parse('org-dartlang-app:///test/aaa_test.dart');
      await d.file('test/aaa_test.dart', '''
        import 'package:test/test.dart';

        void main() {
          group("a", () { // Line 4 from stack trace (match)
            test("a", () {});
          });

          // Custom line 4 (match)
          group("b", location: TestLocation(Uri.parse('$testFileUri'), 4, 0), () {
            test("b", () {});
          });

          // Custom line 4 match but using org-dartlang-app (match)
          group("c", location: TestLocation(Uri.parse('$testFilePackageRelativeUri'), 4, 0), () {
            test("c", () {});
          });

          // Custom different line, same file (no match)
          group("d", location: TestLocation(Uri.parse('$testFileUri'), 5, 0), () {
            test("d", () => throw TestFailure("oh no"));
          });

          // Custom line 4 match but different file (no match)
          group("e", location: TestLocation(Uri.parse('$notTestFileUri'), 4, 0), () {
            test("e", () => throw TestFailure("oh no"));
          });
        }
      ''').create();

      var test = await runTest(['test/aaa_test.dart?line=4']);

      expect(
        test.stdout,
        emitsThrough(contains('+3: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('No matching tests', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
        }
      ''').create();

      var test = await runTest(['test.dart?line=1']);

      expect(
        test.stderr,
        emitsThrough(contains('No tests were found.')),
      );

      await test.shouldExit(exit_codes.noTestsRan);
    });

    test('allows the line anywhere in the stack trace', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void runTest(String name) {
          test(name, () {});
        }

        void main() {
          runTest("a");
          test("b", () {});
        }
      ''').create();

      var test = await runTest(['test.dart?line=8']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });
  });

  group('with test.dart?col=<col> query', () {
    test('selects single test with the matching column', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
            test("b", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?col=11']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('selects multiple tests starting on the same column', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
          test("b", () {});
            test("c", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?col=11']);

      expect(
        test.stdout,
        emitsThrough(contains('+2: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('selects groups with a matching column', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          group("a", () {
            test("b", () {});
          });
            group("b", () {
              test("b", () => throw TestFailure("oh no"));
            });
        }
      ''').create();

      var test = await runTest(['test.dart?col=11']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('No matching tests', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
        }
      ''').create();

      var test = await runTest(['test.dart?col=1']);

      expect(
        test.stderr,
        emitsThrough(contains('No tests were found.')),
      );

      await test.shouldExit(exit_codes.noTestsRan);
    });

    test('allows the col anywhere in the stack trace', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void runTest(String name) {
          test(name, () {});
        }

        void main() {
            runTest("a");
          test("b", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?col=13']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });
  });

  group('with test.dart?line=<line>&col=<col> query', () {
    test('selects test with the matching line and col in the same frame',
        () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          void runTests() {
          test("a", () {});test("b", () => throw TestFailure("oh no"));
          }
          runTests();
          test("c", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?line=5&col=11']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('selects group with the matching line and col', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          group("a", () {
            test("b", () {});
            test("c", () {});
          });
          group("d", () {
            test("e", () => throw TestFailure("oh no"));
          });
        }
      ''').create();

      var test = await runTest(['test.dart?line=4&col=11']);

      expect(
        test.stdout,
        emitsThrough(contains('+2: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('no matching tests - col doesnt match', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
        }
      ''').create();

      var test = await runTest(['test.dart?line=4&col=1']);

      expect(
        test.stderr,
        emitsThrough(contains('No tests were found.')),
      );

      await test.shouldExit(exit_codes.noTestsRan);
    });

    test('no matching tests - line doesnt match', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
        }
      ''').create();

      var test = await runTest(['test.dart?line=1&col=11']);

      expect(
        test.stderr,
        emitsThrough(contains('No tests were found.')),
      );

      await test.shouldExit(exit_codes.noTestsRan);
    });

    test('supports browser tests', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
          test("b", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?line=4&col=11', '-p', 'chrome']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    });

    test('supports node tests', () async {
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("a", () {});
          test("b", () => throw TestFailure("oh no"));
        }
      ''').create();

      var test = await runTest(['test.dart?line=4&col=11', '-p', 'node']);

      expect(
        test.stdout,
        emitsThrough(contains('+1: All tests passed!')),
      );

      await test.shouldExit(0);
    }, retry: 3);
  });

  test('bundles runs by suite, deduplicates tests that match multiple times',
      () async {
    await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test('a', () {});
          test('b', () => throw TestFailure('oh no'));
        }
      ''').create();

    var test = await runTest(['test.dart?line=4', 'test.dart?full-name=a']);

    expect(
      test.stdout,
      emitsThrough(contains('+1: All tests passed!')),
    );

    await test.shouldExit(0);
  });
}
