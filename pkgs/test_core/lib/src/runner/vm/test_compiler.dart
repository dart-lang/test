// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:test_api/backend.dart'; // ignore: deprecated_member_use
import 'package:frontend_server_client/frontend_server_client.dart';

import '../package_version.dart';
import '../../util/package_config.dart';

class CompilationResponse {
  final String? compilerOutput;
  final int errorCount;
  final Uri? kernelOutputUri;

  CompilationResponse(
      {this.compilerOutput, this.errorCount = 0, this.kernelOutputUri});
}

class TestCompiler {
  final _compilePool = Pool(1);
  final String _dillCachePath;
  final Directory _outputDillDirectory;

  late final _outputDill =
      File(p.join(_outputDillDirectory.path, 'output.dill'));
  FrontendServerClient? _frontendServerClient;

  TestCompiler(this._dillCachePath)
      : _outputDillDirectory =
            Directory.systemTemp.createTempSync('dart_test.');

  /// Enqueues a request to compile [mainDart] and returns the result.
  ///
  /// This request may need to wait for ongoing compilations.
  ///
  /// If [dispose] has already been called, then this immediately returns a
  /// failed response indicating the compiler was shut down.
  ///
  /// The entrypoint [mainDart] is wrapped in a script which bootstraps it with
  /// a call to `internalBootstrapVmTest`.
  Future<CompilationResponse> compile(Uri mainDart, Metadata metadata) {
    if (_compilePool.isClosed) {
      return Future.value(CompilationResponse(
          errorCount: 1, compilerOutput: 'Compiler was already shut down.'));
    }
    return _compilePool.withResource(() => _compile(mainDart, metadata));
  }

  Future<void> dispose() async {
    await _compilePool.close();
    _frontendServerClient?.kill();
    _frontendServerClient = null;
    if (_outputDillDirectory.existsSync()) {
      _outputDillDirectory.deleteSync(recursive: true);
    }
  }

  Future<String> _generateEntrypoint(
      Uri testUri, Metadata suiteMetadata) async {
    return '''
        ${suiteMetadata.languageVersionComment ?? await rootPackageLanguageVersionComment}
    import "dart:isolate";

    import "package:test_core/src/bootstrap/vm.dart";

    import "$testUri" as test;

    void main(_, SendPort sendPort) {
      internalBootstrapVmTest(() => test.main, sendPort);
    }
  ''';
  }

  Future<CompilationResponse> _compile(Uri mainUri, Metadata metadata) async {
    var firstCompile = false;
    CompileResult? compilerOutput;
    final contents = await _generateEntrypoint(mainUri, metadata);
    final tempFile = File(p.join(_outputDillDirectory.path, 'test.dart'))
      ..writeAsStringSync(contents);

    if (_frontendServerClient == null) {
      compilerOutput = await _createCompiler(tempFile.uri);
      firstCompile = true;
    } else {
      compilerOutput =
          await _frontendServerClient!.compile(<Uri>[tempFile.uri]);
    }
    // The client is guaranteed initialized at this point.
    final client = _frontendServerClient!;
    final outputPath = compilerOutput?.dillOutput;
    if (outputPath == null) {
      return CompilationResponse(
          compilerOutput: compilerOutput?.compilerOutputLines.join('\n'),
          errorCount: compilerOutput?.errorCount ?? 0);
    }

    final outputFile = File(outputPath);
    final kernelReadyToRun = await outputFile.copy('${tempFile.path}.dill');
    final testCache = File(_dillCachePath);
    // Keep the cache file up-to-date and use the size of the kernel file
    // as an approximation for how many packages are included. Larger files
    // are prefered, since re-using more packages will reduce the number of
    // files the frontend server needs to load and parse.
    if (firstCompile ||
        !testCache.existsSync() ||
        (testCache.lengthSync() < outputFile.lengthSync())) {
      if (!testCache.parent.existsSync()) {
        testCache.parent.createSync(recursive: true);
      }
      await outputFile.copy(_dillCachePath);
    }

    client.accept();
    client.reset();
    return CompilationResponse(
        compilerOutput: compilerOutput?.compilerOutputLines.join('\n'),
        errorCount: compilerOutput?.errorCount ?? 0,
        kernelOutputUri: kernelReadyToRun.absolute.uri);
  }

  Future<CompileResult?> _createCompiler(Uri testUri) async {
    final platformDill = 'lib/_internal/vm_platform_strong.dill';
    final sdkRoot =
        Directory(p.relative(p.join(Platform.resolvedExecutable, '..', '..')))
            .uri;
    var client = _frontendServerClient = await FrontendServerClient.start(
      testUri.toString(),
      _outputDill.path,
      platformDill,
      sdkRoot: sdkRoot.path,
      packagesJson: (await packageConfigUri).toFilePath(),
      printIncrementalDependencies: false,
    );
    return client.compile();
  }
}
