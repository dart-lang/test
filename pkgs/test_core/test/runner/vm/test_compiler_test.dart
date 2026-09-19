// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
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

      await fakeClient.compileCalled();

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

      await fakeClient.compileCalled();

      expect(fakeClient.isCompileCalled, isTrue);
      expect(fakeClient.isKilled, isFalse);

      final disposeFuture = compiler.dispose();

      await expectLater(disposeFuture, completes);
      expect(fakeClient.isKilled, isTrue);

      final response = await compileFuture;
      expect(response.errorCount, 1);
      expect(response.compilerOutput, contains('Compiler no longer active'));
    });

    test('release deletes kernel files which are not cached', () async {
      final (fakeClient, clientStarter) = FakeFrontendServerClient.create;
      final compiler = TestCompiler(
        p.join(d.sandbox, 'dill_cache'),
        clientFactory: clientStarter,
      );
      addTearDown(compiler.dispose);

      // The largest dill is the one that gets cached, so the second compile
      // here is the one that has to survive until the compiler is disposed.
      final small = await _compile(
        compiler,
        fakeClient,
        testPath,
        name: 'small',
        dillSize: 32,
      );
      final large = await _compile(
        compiler,
        fakeClient,
        testPath,
        name: 'large',
        dillSize: 64,
      );
      final smallKernel = File.fromUri(small.kernelOutputUri!);
      final largeKernel = File.fromUri(large.kernelOutputUri!);

      await compiler.release(small.kernelOutputUri!);
      expect(smallKernel.existsSync(), isFalse);
      expect(largeKernel.existsSync(), isTrue);

      await compiler.release(large.kernelOutputUri!);
      expect(
        largeKernel.existsSync(),
        isTrue,
        reason: 'the dill to cache should be kept until dispose',
      );

      await compiler.dispose();
      expect(largeKernel.existsSync(), isFalse);
      expect(
        Directory(
          d.sandbox,
        ).listSync().map((entity) => p.basename(entity.path)),
        contains(startsWith('dill_cache.')),
        reason: 'the dill to cache should be copied on dispose',
      );
    });

    test(
      'a released kernel file is deleted once a larger one replaces it',
      () async {
        final (fakeClient, clientStarter) = FakeFrontendServerClient.create;
        final compiler = TestCompiler(
          p.join(d.sandbox, 'dill_cache'),
          clientFactory: clientStarter,
        );
        addTearDown(compiler.dispose);

        final small = await _compile(
          compiler,
          fakeClient,
          testPath,
          name: 'small',
          dillSize: 32,
        );
        final smallKernel = File.fromUri(small.kernelOutputUri!);
        await compiler.release(small.kernelOutputUri!);
        expect(smallKernel.existsSync(), isTrue);

        await _compile(
          compiler,
          fakeClient,
          testPath,
          name: 'large',
          dillSize: 64,
        );
        expect(smallKernel.existsSync(), isFalse);
      },
    );
  });
}

/// Compiles [testPath] with [compiler], responding through [fakeClient] with a
/// dill file of [dillSize] bytes.
Future<CompilationResponse> _compile(
  TestCompiler compiler,
  FakeFrontendServerClient fakeClient,
  String testPath, {
  required String name,
  required int dillSize,
}) async {
  final outputDill = p.join(d.sandbox, '$name.dill');
  File(outputDill).writeAsBytesSync(List.filled(dillSize, 0));
  final compileFuture = compiler.compile(
    Uri.file(testPath),
    Metadata(languageVersionComment: '// @dart=3.0'),
  );
  fakeClient.completeCompile(
    FakeCompileResult(dillOutput: outputDill, errorCount: 0),
  );
  return await compileFuture;
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
  /// Compile calls which have not been given a result yet.
  final _pendingCompiles = Queue<Completer<CompileResult>>();

  /// Results which were provided before the matching compile call.
  final _queuedResults = Queue<CompileResult>();

  final _compileCalls = StreamController<void>.broadcast();

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

  /// Completes once [compile] has been called at least [count] times.
  Future<void> compileCalled([int count = 1]) async {
    while (compileCallCount < count) {
      await _compileCalls.stream.first;
    }
  }

  @override
  Future<CompileResult> compile([List<Uri>? sources]) {
    isCompileCalled = true;
    compileCallCount++;
    _compileCalls.add(null);
    if (_queuedResults.isNotEmpty) {
      return Future.value(_queuedResults.removeFirst());
    }
    final completer = Completer<CompileResult>();
    _pendingCompiles.add(completer);
    return completer.future;
  }

  /// Provides [result] for the next compile, whether or not it has started.
  void completeCompile(CompileResult result) {
    if (_pendingCompiles.isEmpty) {
      _queuedResults.add(result);
    } else {
      _pendingCompiles.removeFirst().complete(result);
    }
  }

  @override
  bool kill({ProcessSignal processSignal = ProcessSignal.sigterm}) {
    isKilled = true;
    while (_pendingCompiles.isNotEmpty) {
      _pendingCompiles.removeFirst().completeError(StateError('Killed'));
    }
    return true;
  }

  @override
  void accept() {}

  @override
  void reset() {}
}
