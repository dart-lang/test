// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
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

  const CompilationResponse(
      {this.compilerOutput, this.errorCount = 0, this.kernelOutputUri});

  static const _wasShutdown = CompilationResponse(
      errorCount: 1, compilerOutput: 'Compiler no longer active.');
}

class TestCompiler {
  final _closeMemo = AsyncMemoizer<void>();

  /// Each language version that appears in test files gets its own compiler,
  /// to ensure that all language modes are supported (such as sound and
  /// unsound null safety).
  final _compilerForLanguageVersion =
      <String, _TestCompilerForLanguageVersion>{};

  /// A prefix used for the dill files for each compiler that is created.
  final String _dillCachePrefix;

  /// No work is done until the first call to [compile] is recieved, at which
  /// point the compiler process is started.
  TestCompiler(this._dillCachePrefix);

  /// Compiles [mainDart], using a separate compiler per language version of
  /// the tests.
  Future<CompilationResponse> compile(Uri mainDart, Metadata metadata) async {
    if (_closeMemo.hasRun) return CompilationResponse._wasShutdown;
    var languageVersionComment = metadata.languageVersionComment ??
        await rootPackageLanguageVersionComment;
    var compiler = _compilerForLanguageVersion.putIfAbsent(
        languageVersionComment,
        () => _TestCompilerForLanguageVersion(
            _dillCachePrefix, languageVersionComment));
    return compiler.compile(mainDart);
  }

  Future<void> dispose() => _closeMemo.runOnce(() => Future.wait([
        for (var compiler in _compilerForLanguageVersion.values)
          compiler.dispose(),
      ]));
}

class _TestCompilerForLanguageVersion {
  final _closeMemo = AsyncMemoizer();
  final _compilePool = Pool(1);
  final String _dillCachePath;
  FrontendServerClient? _frontendServerClient;
  final String _languageVersionComment;
  late final _outputDill =
      File(p.join(_outputDillDirectory.path, 'output.dill'));
  final _outputDillDirectory =
      Directory.systemTemp.createTempSync('dart_test.');

  _TestCompilerForLanguageVersion(
      String dillCachePrefix, this._languageVersionComment)
      : _dillCachePath =
            '$dillCachePrefix.${base64.encode(utf8.encode(_languageVersionComment.replaceAll(' ', '')))}';

  String _generateEntrypoint(Uri testUri) {
    return '''
    $_languageVersionComment
    import "dart:isolate";

    import "package:test_core/src/bootstrap/vm.dart";

    import "$testUri" as test;

    void main(_, SendPort sendPort) {
      internalBootstrapVmTest(() => test.main, sendPort);
    }
  ''';
  }

  Future<CompilationResponse> compile(Uri mainUri) =>
      _compilePool.withResource(() => _compile(mainUri));

  Future<CompilationResponse> _compile(Uri mainUri) async {
    if (_closeMemo.hasRun) return CompilationResponse._wasShutdown;
    var firstCompile = false;
    CompileResult? compilerOutput;
    final tempFile = File(p.join(_outputDillDirectory.path, 'test.dart'))
      ..writeAsStringSync(_generateEntrypoint(mainUri));

    try {
      if (_frontendServerClient == null) {
        compilerOutput = await _createCompiler(tempFile.uri);
        firstCompile = true;
      } else {
        compilerOutput =
            await _frontendServerClient!.compile(<Uri>[tempFile.uri]);
      }
    } catch (e, s) {
      if (_closeMemo.hasRun) return CompilationResponse._wasShutdown;
      return CompilationResponse(errorCount: 1, compilerOutput: '$e\n$s');
    } finally {
      _frontendServerClient?.accept();
      _frontendServerClient?.reset();
    }

    // The client is guaranteed initialized at this point.
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

  Future<void> dispose() => _closeMemo.runOnce(() async {
        await _compilePool.close();
        _frontendServerClient?.kill();
        _frontendServerClient = null;
        if (_outputDillDirectory.existsSync()) {
          _outputDillDirectory.deleteSync(recursive: true);
        }
      });
}
