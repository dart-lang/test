// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import '../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  group('with the --coverage flag,', () {
    late Directory coverageDirectory;
    late String pkgDir;

    Future<void> validateTest(TestProcess test) async {
      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    }

    Future<Map<String, HitMap>> validateCoverage(
      TestProcess test,
      String coveragePath,
    ) async {
      await validateTest(test);

      final coverageFile = File(p.join(coverageDirectory.path, coveragePath));
      final coverage = await coverageFile.readAsString();
      final jsonCoverage = json.decode(coverage)['coverage'] as List<dynamic>;
      expect(jsonCoverage, isNotEmpty);

      return HitMap.parseJson(jsonCoverage.cast<Map<String, dynamic>>());
    }

    setUp(() async {
      coverageDirectory = await Directory.systemTemp.createTemp(
        'test_coverage',
      );

      final outerDirectory = d.dir(d.sandbox, [
        d.dir('fake_package', [
          d.dir('lib', [
            d.file('calculate.dart', '''
            int calculate(int x) {
              if (x % 2 == 0) {
                return x * 2;
              } else {
                return x * 3;
              }
            }
          '''),
          ]),
          d.dir('test', [
            d.file('test.dart', '''
            import 'package:fake_package/calculate.dart';
            import 'package:test/test.dart';

            void main() {
              test('test 1', () {
                expect(calculate(6), 12);
              });
            }
          '''),
          ]),
          d.file('pubspec.yaml', '''
name: fake_package
version: 1.0.0
environment:
  sdk: ^3.5.0
dev_dependencies:
  test: ^1.26.2
        '''),
        ]),
        d.dir('fake_client', [
          d.dir('lib', [
            d.file('calculate.dart', '''
            import 'package:fake_package/calculate.dart' as fake_package;

            int calculate(int x) {
              return fake_package.calculate(x);
            }
          '''),
          ]),
          d.dir('test', [
            d.file('test.dart', '''
            import 'package:fake_client/calculate.dart';
            import 'package:test/test.dart';

            void main() {
              test('test 1', () {
                expect(calculate(6), 12);
              });
            }
          '''),
          ]),
          d.file('pubspec.yaml', '''
name: fake_client
version: 1.0.0
environment:
  sdk: ^3.5.0
dependencies:
  fake_package:
    path: ../fake_package
dev_dependencies:
  test: ^1.26.2
        '''),
        ]),
      ]);
      await outerDirectory.create();
      pkgDir = p.join(d.sandbox, 'fake_package');
    });

    tearDown(() async {
      await coverageDirectory.delete(recursive: true);
    });

    test('gathers coverage for VM tests', () async {
      await (await runPub(['get'], workingDirectory: pkgDir)).shouldExit(0);
      var test = await runTest(
        ['--coverage', coverageDirectory.path, 'test/test.dart'],
        packageConfig: p.join(pkgDir, '.dart_tool/package_config.json'),
        workingDirectory: pkgDir,
      );
      final coverage = await validateCoverage(test, 'test/test.dart.vm.json');
      final hitmap = coverage['package:fake_package/calculate.dart']!;
      expect(hitmap.lineHits, {1: 1, 2: 2, 3: 1, 5: 0});
      expect(hitmap.funcHits, isNull);
      expect(hitmap.branchHits, isNull);
    });

    test('gathers branch coverage for VM tests', () async {
      await (await runPub(['get'], workingDirectory: pkgDir)).shouldExit(0);
      var test = await runTest(
        [
          '--coverage',
          coverageDirectory.path,
          '--branch-coverage',
          'test/test.dart',
        ],
        vmArgs: ['--branch-coverage'],
        packageConfig: p.join(pkgDir, '.dart_tool/package_config.json'),
        workingDirectory: pkgDir,
      );
      final coverage = await validateCoverage(test, 'test/test.dart.vm.json');
      final hitmap = coverage['package:fake_package/calculate.dart']!;
      expect(hitmap.lineHits, {1: 1, 2: 2, 3: 1, 5: 0});
      expect(hitmap.funcHits, isNull);
      expect(hitmap.branchHits, {1: 1, 2: 1, 4: 0});
    });

    test('gathers lcov coverage for VM tests', () async {
      await (await runPub(['get'], workingDirectory: pkgDir)).shouldExit(0);
      final lcovFile = p.join(coverageDirectory.path, 'lcov.info');
      var test = await runTest(
        ['--coverage-path', lcovFile, 'test/test.dart'],
        packageConfig: p.join(pkgDir, '.dart_tool/package_config.json'),
        workingDirectory: pkgDir,
      );
      await validateTest(test);
      expect(File(lcovFile).readAsStringSync(), '''
SF:${p.join(pkgDir, 'lib', 'calculate.dart')}
DA:1,1
DA:2,2
DA:3,1
DA:5,0
LF:4
LH:3
end_of_record
''');
    });

    test('gathers coverage for tests in multiple packages', () async {
      final clientPkgDir = p.join(d.sandbox, 'fake_client');
      await (await runPub([
        'get',
      ], workingDirectory: clientPkgDir)).shouldExit(0);
      final lcovFile = p.join(coverageDirectory.path, 'lcov.info');
      var test = await runTest(
        [
          '--coverage-path',
          lcovFile,
          '--coverage-package=fake_.*',
          'test/test.dart',
        ],
        packageConfig: p.join(clientPkgDir, '.dart_tool/package_config.json'),
        workingDirectory: clientPkgDir,
      );
      await validateTest(test);
      expect(File(lcovFile).readAsStringSync(), '''
SF:${p.join(clientPkgDir, 'lib', 'calculate.dart')}
DA:3,1
DA:4,1
LF:2
LH:2
end_of_record
SF:${p.join(pkgDir, 'lib', 'calculate.dart')}
DA:1,1
DA:2,2
DA:3,1
DA:5,0
LF:4
LH:3
end_of_record
''');
    });

    test('gathers coverage for package in a workspace', () async {
      await d.dir(d.sandbox, [
        d.dir('fake_workspace', [
          d.file('pubspec.yaml', '''
name: fake_workspace
version: 1.0.0
environment:
  sdk: ^3.5.0
workspace:
  - workspace_package
          '''),
          d.dir('workspace_package', [
            d.file('pubspec.yaml', '''
name: workspace_package
version: 1.0.0
environment:
  sdk: ^3.5.0
resolution: workspace
dev_dependencies:
  test: ^1.26.2
            '''),
            d.dir('lib', [
              d.file('calculate.dart', '''
              int calculate(int x) {
                if (x % 2 == 0) {
                  return x * 2;
                } else {
                  return x * 3;
                }
              }
              '''),
            ]),
            d.dir('test', [
              d.file('test.dart', '''
              import 'package:workspace_package/calculate.dart';
              import 'package:test/test.dart';

              void main() {
                test('test 1', () {
                  expect(calculate(6), 12);
                });
              }
              '''),
            ]),
          ]),
        ]),
      ]).create();

      final pkgDir = p.join(d.sandbox, 'fake_workspace', 'workspace_package');
      await (await runPub(['get'], workingDirectory: pkgDir)).shouldExit(0);
      final lcovFile = p.join(coverageDirectory.path, 'lcov.info');
      var test = await runTest(
        ['--coverage-path', lcovFile, 'test/test.dart'],
        packageConfig: p.join(pkgDir, '../.dart_tool/package_config.json'),
        workingDirectory: pkgDir,
      );
      await validateTest(test);
      expect(File(lcovFile).readAsStringSync(), '''
SF:${p.join(pkgDir, 'lib', 'calculate.dart')}
DA:1,1
DA:2,2
DA:3,1
DA:5,0
LF:4
LH:3
end_of_record
''');
    });

    test('gathers coverage for Chrome tests', () async {
      await (await runPub(['get'], workingDirectory: pkgDir)).shouldExit(0);
      var test = await runTest(
        [
          '--coverage',
          coverageDirectory.path,
          'test/test.dart',
          '-p',
          'chrome',
        ],
        packageConfig: p.join(pkgDir, '.dart_tool/package_config.json'),
        workingDirectory: pkgDir,
      );
      await validateCoverage(test, 'test/test.dart.chrome.json');
    });

    test(
      'gathers coverage for Chrome tests when JS files contain unicode characters',
      () async {
        final sourceMapFileContent =
            '{"version":3,"file":"","sources":[],"names":[],"mappings":""}';
        final jsContent = '''
        (function() {
          '© '
          window.foo = function foo() {
            return 'foo';
          };
        })({

          '© ': ''
          });
      ''';
        await d.file('file_with_unicode.js', jsContent).create();
        await d.file('file_with_unicode.js.map', sourceMapFileContent).create();

        await d.file('js_with_unicode_test.dart', '''
        import 'dart:async';
        import 'dart:js_interop';
        import 'dart:js_interop_unsafe';

        import 'package:test/src/runner/browser/dom.dart' as dom;
        import 'package:test/test.dart';

        Future<void> loadScript(String src) async {
          final controller = StreamController();
          final scriptLoaded = controller.stream.first;
          final script = dom.createHTMLScriptElement()..src = src;
          script.addEventListener('load',
              (_) {
                controller.add('loaded');
              });
          dom.document.body!.appendChild(script);
          await scriptLoaded.timeout(Duration(seconds: 1));
        }

        void main() {
          test("test 1", () async {
            await loadScript('file_with_unicode.js');
            expect(dom.window.getProperty('foo'.toJS), isNotNull);
            dom.window.callMethodVarArgs('foo'.toJS, []);
            expect(true, isTrue);
          });
        }
      ''').create();

        final jsBytes = utf8.encode(jsContent);
        final jsLatin1 = latin1.decode(jsBytes);
        final jsUtf8 = utf8.decode(jsBytes);
        expect(
          jsLatin1,
          isNot(jsUtf8),
          reason: 'test setup: should have decoded differently',
        );

        const functionPattern = 'function foo';
        expect([jsLatin1, jsUtf8], everyElement(contains(functionPattern)));
        expect(
          jsLatin1.indexOf(functionPattern),
          isNot(jsUtf8.indexOf(functionPattern)),
          reason:
              'test setup: decoding should have shifted the position of the function',
        );

        var test = await runTest([
          '--coverage',
          coverageDirectory.path,
          'js_with_unicode_test.dart',
          '-p',
          'chrome',
        ]);
        await validateCoverage(test, 'js_with_unicode_test.dart.chrome.json');
      },
    );
  });
}
