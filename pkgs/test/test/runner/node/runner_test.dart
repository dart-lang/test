// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@Tags(['node'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/src/runner/executable_settings.dart';
import 'package:test/test.dart';
import 'package:test_core/src/util/io.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../io.dart';

final _success = '''
  import 'package:test/test.dart';

  void main() {
    test("success", () {});
  }
''';

final _failure = '''
  import 'package:test/test.dart';

  void main() {
    test("failure", () => throw TestFailure("oh no"));
  }
''';

({int major, String full})? _nodeVersion;

({int major, String full}) _readNodeVersion() {
  final process = Process.runSync(
    ExecutableSettings(
      linuxExecutable: 'node',
      macOSExecutable: 'node',
      windowsExecutable: 'node.exe',
    ).executable,
    ['--version'],
    stdoutEncoding: utf8,
  );
  if (process.exitCode != 0) {
    throw const OSError('Could not run node --version');
  }

  final version = RegExp(r'v(\d+)\..*');
  final parsed = version.firstMatch(process.stdout as String)!;
  return (major: int.parse(parsed.group(1)!), full: process.stdout);
}

String? skipBelowMajorNodeVersion(int minimumMajorVersion) {
  final (:major, :full) = _nodeVersion ??= _readNodeVersion();
  if (major < minimumMajorVersion) {
    return 'This test requires Node $minimumMajorVersion.x or later, '
        'but is running on $full';
  }

  return null;
}

String? skipAboveMajorNodeVersion(int maximumMajorVersion) {
  final (:major, :full) = _nodeVersion ??= _readNodeVersion();
  if (major > maximumMajorVersion) {
    return 'This test requires Node $maximumMajorVersion.x or older, '
        'but is running on $full';
  }

  return null;
}

void main() {
  setUpAll(precompileTestExecutable);

  group('fails gracefully if', () {
    test('a test file fails to compile', () async {
      await d.file('test.dart', 'invalid Dart file').create();
      var test = await runTest(['-p', 'node', 'test.dart']);

      expect(
          test.stdout,
          containsInOrder([
            'Error: Compilation failed.',
            '-1: loading test.dart [E]',
            'Failed to load "test.dart": dart2js failed.'
          ]));
      await test.shouldExit(1);
    });

    test('a test file throws', () async {
      await d.file('test.dart', "void main() => throw 'oh no';").create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '-1: loading test.dart [E]',
            'Failed to load "test.dart": oh no'
          ]));
      await test.shouldExit(1);
    });

    test("a test file doesn't have a main defined", () async {
      await d.file('test.dart', 'void foo() {}').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '-1: loading test.dart [E]',
            'Failed to load "test.dart": No top-level main() function defined.'
          ]));
      await test.shouldExit(1);
    }, skip: 'https://github.com/dart-lang/test/issues/894');

    test('a test file has a non-function main', () async {
      await d.file('test.dart', 'int main;').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '-1: loading test.dart [E]',
            'Failed to load "test.dart": Top-level main getter is not a function.'
          ]));
      await test.shouldExit(1);
    }, skip: 'https://github.com/dart-lang/test/issues/894');

    test('a test file has a main with arguments', () async {
      await d.file('test.dart', 'void main(arg) {}').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '-1: loading test.dart [E]',
            'Failed to load "test.dart": Top-level main() function takes arguments.'
          ]));
      await test.shouldExit(1);
    });
  });

  group('runs successful tests', () {
    test('on Node and the VM', () async {
      await d.file('test.dart', _success).create();
      var test = await runTest(['-p', 'node', '-p', 'vm', 'test.dart']);

      expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
      await test.shouldExit(0);
    });

    // Regression test; this broke in 0.12.0-beta.9.
    test('on a file in a subdirectory', () async {
      await d.dir('dir', [d.file('test.dart', _success)]).create();

      var test = await runTest(['-p', 'node', 'dir/test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });

    test('compiled with dart2wasm', () async {
      await d.file('test.dart', _success).create();
      var test =
          await runTest(['-p', 'node', '--compiler', 'dart2wasm', 'test.dart']);

      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    }, skip: skipBelowMajorNodeVersion(22));
  });

  test('defines a node environment constant', () async {
    await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test", () {
            expect(const bool.fromEnvironment("node"), isTrue);
          });
        }
      ''').create();

    var test = await runTest(['-p', 'node', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  test('runs failing tests that fail only on node', () async {
    await d.file('test.dart', '''
        import 'package:path/path.dart' as p;
        import 'package:test/test.dart';

        void main() {
          test("test", () {
            if (const bool.fromEnvironment("node")) {
              throw TestFailure("oh no");
            }
          });
        }
      ''').create();

    var test =
        await runTest(['-p', 'node', '-p', 'vm', '-c', 'dart2js', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('+1 -1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('runs failing tests that fail only on node (with dart2wasm)', () async {
    await d.file('test.dart', '''
        import 'package:path/path.dart' as p;
        import 'package:test/test.dart';

        void main() {
          test("test", () {
            if (const bool.fromEnvironment("node")) {
              throw TestFailure("oh no");
            }
          });
        }
      ''').create();

    var test = await runTest([
      '-p',
      'node',
      '-p',
      'vm',
      '-c',
      'dart2js',
      '-c',
      'dart2wasm',
      'test.dart'
    ]);
    expect(test.stdout, emitsThrough(contains('+1 -2: Some tests failed.')));
    await test.shouldExit(1);
  }, skip: skipBelowMajorNodeVersion(22));

  test(
    'gracefully handles wasm errors on old node versions',
    () async {
      // Old Node.JS versions can't read the WebAssembly modules emitted by
      // dart2wasm. The node process exits before connecting to the server
      // opened by the test runner, leading to timeouts. So, this is a
      // regression test for https://github.com/dart-lang/test/pull/2259#issuecomment-2307868442
      await d.file('test.dart', '''
        import 'package:test/test.dart';

        void main() {
          test("test", () {
            // Should pass on newer node versions
          });
        }
      ''').create();

      var test = await runTest(['-p', 'node', '-c', 'dart2wasm', 'test.dart']);
      expect(
        test.stdout,
        emitsInOrder([
          emitsThrough(
              contains('Node exited before connecting to the test channel.')),
          emitsThrough(contains('-1: Some tests failed.')),
        ]),
      );
      await test.shouldExit(1);
    },
    skip: skipAboveMajorNodeVersion(21),
  );

  test('forwards prints from the Node test', () async {
    await d.file('test.dart', '''
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        test("test", () {
          print("Hello,");
          return Future(() => print("world!"));
        });
      }
    ''').create();

    var test = await runTest(['-p', 'node', 'test.dart']);
    expect(test.stdout, emitsInOrder([emitsThrough('Hello,'), 'world!']));
    await test.shouldExit(0);
  });

  test('forwards raw JS prints from the Node test', () async {
    await d.file('test.dart', '''
      import 'dart:async';
      import 'dart:js_interop';
      
      import 'package:test/test.dart';
      
      @JS('console.log')
      external void log(JSString value);
      
      void main() {
        test('test', () {
          log('Hello,'.toJS);
          return Future(() => log('world!'.toJS));
        });
      }
    ''').create();

    var test = await runTest(['-p', 'node', 'test.dart']);
    expect(test.stdout, emitsInOrder([emitsThrough('Hello,'), 'world!']));
    await test.shouldExit(0);
  });

  test('dartifies stack traces for JS-compiled tests by default', () async {
    await d.file('test.dart', _failure).create();

    var test = await runTest(['-p', 'node', '--verbose-trace', 'test.dart']);
    expect(test.stdout,
        containsInOrder([' main.<fn>', 'package:test', 'dart:async/zone.dart']),
        skip: 'https://github.com/dart-lang/sdk/issues/41949');
    await test.shouldExit(1);
  });

  test("doesn't dartify stack traces for JS-compiled tests with --js-trace",
      () async {
    await d.file('test.dart', _failure).create();

    var test = await runTest(
        ['-p', 'node', '--verbose-trace', '--js-trace', 'test.dart']);
    expect(test.stdoutStream(), neverEmits(endsWith(' main.<fn>')));
    expect(test.stdoutStream(), neverEmits(contains('package:test')));
    expect(test.stdoutStream(), neverEmits(contains('dart:async/zone.dart')));
    expect(test.stdout, emitsThrough(contains('-1: Some tests failed.')));
    await test.shouldExit(1);
  });

  test('supports node_modules in the package directory', () async {
    await d.dir('node_modules', [
      d.dir('my_module', [d.file('index.js', 'module.exports.value = 12;')])
    ]).create();

    await d.file('test.dart', '''
      import 'dart:js_interop';
      
      import 'package:test/test.dart';
      
      @JS()
      external MyModule require(String name);
      
      @JS()
      extension type MyModule(JSObject _) implements JSObject {
        external int get value;
      }
      
      void main() {
        test('can load from a module', () {
          expect(require('my_module').value, equals(12));
        });
      }
    ''').create();

    var test = await runTest(['-p', 'node', 'test.dart']);
    expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
    await test.shouldExit(0);
  });

  group('with onPlatform', () {
    test('respects matching Skips', () async {
      await d.file('test.dart', '''
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("fail", () => throw 'oh no', onPlatform: {"node": Skip()});
        }
      ''').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(test.stdout, emitsThrough(contains('+0 ~1: All tests skipped.')));
      await test.shouldExit(0);
    });

    test('ignores non-matching Skips', () async {
      await d.file('test.dart', '''
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("success", () {}, onPlatform: {"browser": Skip()});
        }
      ''').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });

    test('matches the current OS', () async {
      await d.file('test.dart', '''
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("fail", () => throw 'oh no',
              onPlatform: {"${currentOS.identifier}": Skip()});
        }
      ''').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(test.stdout, emitsThrough(contains('+0 ~1: All tests skipped.')));
      await test.shouldExit(0);
    });

    test("doesn't match a different OS", () async {
      await d.file('test.dart', '''
        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("success", () {}, onPlatform: {"$otherOS": Skip()});
        }
      ''').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });
  });

  group('with an @OnPlatform annotation', () {
    test('respects matching Skips', () async {
      await d.file('test.dart', '''
        @OnPlatform(const {"js": const Skip()})

        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("fail", () => throw 'oh no');
        }
      ''').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(test.stdout, emitsThrough(contains('~1: All tests skipped.')));
      await test.shouldExit(0);
    });

    test('ignores non-matching Skips', () async {
      await d.file('test.dart', '''
        @OnPlatform(const {"vm": const Skip()})

        import 'dart:async';

        import 'package:test/test.dart';

        void main() {
          test("success", () {});
        }
      ''').create();

      var test = await runTest(['-p', 'node', 'test.dart']);
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });
  });
}
