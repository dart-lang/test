// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

final bool supportsCliCompiler = () {
  try {
    var current = Version.parse(Platform.version.split(' ').first);
    return current > Version.parse('3.13.0-139.0.dev');
  } catch (_) {
    return false;
  }
}();

void main() {
  late String testPath;
  late String testCorePath;
  late String testApiPath;

  setUpAll(() async {
    await precompileTestExecutable();

    testPath = await packageDir;
    final testPathParts = p.split(testPath);
    testCorePath = p.joinAll(
      testPathParts.take(testPathParts.length - 1).followedBy(['test_core']),
    );
    testApiPath = p.joinAll(
      testPathParts.take(testPathParts.length - 1).followedBy(['test_api']),
    );
  });

  // The test sandbox must be set up as a valid Dart package (with its own
  // pubspec.yaml, running `pub get` to generate a valid package_config.json,
  // and putting the entrypoint under the correct package root). This is required
  // for the `cli` compiler (`dart build cli`), which requires the entrypoint
  // target to reside inside a package defined in the package config.
  setUp(() async {
    await d
        .file('pubspec.yaml', _pubspec(testPath, testCorePath, testApiPath))
        .create();

    await (await runPub(['get'], workingDirectory: d.sandbox)).shouldExit(0);
  });

  for (var compiler in ['exe', 'cli']) {
    test(
      'gracefully handles an early test suite exit with the $compiler compiler',
      () async {
        await d.dir('test', [
          d.file('test.dart', '''
        import 'dart:io';

        import 'package:test/test.dart';

        void main() {
          test('runs', () {});
          test('exits', () {
            exit(0);
          });
        }'''),
        ]).create();

        var test = await runTest(
          ['--compiler', compiler, 'test/test.dart'],
          packageConfig: p.join(d.sandbox, '.dart_tool/package_config.json'),
          workingDirectory: d.sandbox,
        );
        expect(
          test.stdout,
          containsInOrder([
            '+1: [VM, ${compiler == 'exe' ? 'Exe' : 'Cli'}] exits - did not complete [E]',
            '+1: Some tests failed.',
          ]),
        );
        await test.shouldExit(1);
      },
      skip: compiler == 'cli' && !supportsCliCompiler
          ? 'Dart version does not support build cli'
          : null,
    );
  }
}

String _pubspec(String testPath, String testCorePath, String testApiPath) =>
    '''
name: mypackage
version: 1.0.0
environment:
  sdk: ^3.5.0
dev_dependencies:
  test: any
dependency_overrides:
  test:
    path: $testPath
  test_core:
    path: $testCorePath
  test_api:
    path: $testApiPath
''';
