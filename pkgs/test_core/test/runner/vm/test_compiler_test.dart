// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:frontend_server_client/frontend_server_client.dart';
import 'package:path/path.dart' as p;
import 'package:test/fake.dart';
import 'package:test/test.dart';
import 'package:test_api/backend.dart';
import 'package:test_core/src/runner/vm/test_compiler.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('VM test templates', () {
    test('include package config URI variable', () async {
      // This variable is read through the VM service and should not be removed.
      final template = testBootstrapContents(
        testUri: Uri.file('foo.dart'),
        languageVersionComment: '// version comment',
        packageConfigUri: Uri.file('package_config.json'),
        testType: VmTestType.isolate,
      );
      final lines = LineSplitter.split(template).map((line) => line.trim());
      expect(
        lines,
        contains("const packageConfigLocation = 'package_config.json';"),
      );
    });
  });

  group('TestCompiler (integration)', () {
    late String testPath;
    late TestCompiler compiler;

    setUp(() async {
      await d.file('a_test.dart', 'void main() {}').create();
      testPath = p.join(d.sandbox, 'a_test.dart');
      compiler = TestCompiler(p.join(d.sandbox, 'dill_cache'));
    });

    tearDown(() async {
      await compiler.dispose();
    });

    test('can compile a test', () async {
      final response = await compiler.compile(Uri.file(testPath), Metadata());
      expect(response.errorCount, 0);
      expect(response.kernelOutputUri, isNotNull);
      expect(File(response.kernelOutputUri!.toFilePath()).existsSync(), isTrue);
    });
  });

  group('TestCompiler (with fakes)', () {
    late String testPath;

    setUp(() async {
      await d.file('a_test.dart', 'void main() {}').create();
      testPath = p.join(d.sandbox, 'a_test.dart');
    });

    test('can compile successfully with fake', () async {
      final (fakeClient, clientStarter) = FakeFrontendServerClient.create;
      final compiler = TestCompiler(
        p.join(d.sandbox, 'dill_cache'),
        clientFactory: clientStarter,
      );

      final compileFuture = compiler.compile(
        Uri.file(testPath),
        Metadata(languageVersionComment: '// @dart=3.0'),
      );

      await pumpEventQueue();

      final outputDill = p.join(d.sandbox, 'output.dill');
      File(outputDill).createSync();

      fakeClient.completeCompile(
        FakeCompileResult(
          dillOutput: outputDill,
          errorCount: 0,
          compilerOutputLines: [],
        ),
      );

      final response = await compileFuture;
      expect(response.errorCount, 0);
      expect(response.kernelOutputUri, isNotNull);

      await compiler.dispose();
    });

    test('dispose kills active compiler and completes immediately', () async {
      final (fakeClient, clientStarter) = FakeFrontendServerClient.create;
      final compiler = TestCompiler(
        p.join(d.sandbox, 'dill_cache'),
        clientFactory: clientStarter,
      );

      final compileFuture = compiler.compile(
        Uri.file(testPath),
        Metadata(languageVersionComment: '// @dart=3.0'),
      );

      await pumpEventQueue();

      expect(fakeClient.isCompileCalled, isTrue);
      expect(fakeClient.isKilled, isFalse);

      final disposeFuture = compiler.dispose();

      await expectLater(disposeFuture, completes);
      expect(fakeClient.isKilled, isTrue);

      final response = await compileFuture;
      expect(response.errorCount, 1);
      expect(response.compilerOutput, contains('Compiler no longer active'));
    });
  });
}

class FakeCompileResult extends Fake implements CompileResult {
  @override
  final String? dillOutput;
  @override
  final int errorCount;
  @override
  final Iterable<String> compilerOutputLines;
  @override
  final Iterable<Uri> newSources;
  @override
  final Iterable<Uri> removedSources;

  FakeCompileResult({
    this.dillOutput,
    this.errorCount = 0,
    this.compilerOutputLines = const [],
    this.newSources = const [],
    this.removedSources = const [],
  });
}

class FakeFrontendServerClient extends Fake implements FrontendServerClient {
  var _compileCompleter = Completer<CompileResult>();
  bool isKilled = false;
  bool isCompileCalled = false;
  int compileCallCount = 0;

  static (FakeFrontendServerClient, FrontendClientFactory) get create {
    final fakeClient = FakeFrontendServerClient();
    return (
      fakeClient,
      (
        _,
        _,
        _, {
        List<String>? enabledExperiments,
        bool printIncrementalDependencies = true,
        String sdkRoot = '',
        String packagesJson = '',
        String? nativeAssets,
      }) async => fakeClient,
    );
  }

  @override
  Future<CompileResult> compile([List<Uri>? sources]) {
    isCompileCalled = true;
    compileCallCount++;
    if (_compileCompleter.isCompleted) {
      _compileCompleter = Completer<CompileResult>();
    }
    return _compileCompleter.future;
  }

  void completeCompile(CompileResult result) {
    if (!_compileCompleter.isCompleted) {
      _compileCompleter.complete(result);
    }
  }

  @override
  bool kill({ProcessSignal processSignal = ProcessSignal.sigterm}) {
    isKilled = true;
    if (!_compileCompleter.isCompleted) {
      _compileCompleter.completeError(StateError('Killed'));
    }
    return true;
  }

  @override
  void accept() {}

  @override
  void reset() {}
}
