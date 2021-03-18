// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test_api/backend.dart'; // ignore: deprecated_member_use
import 'package:frontend_server_client/frontend_server_client.dart';

import '../package_version.dart';

/// A request to the [TestCompiler] for recompilation.
class _CompilationRequest {
  _CompilationRequest(this.mainUri, this.result, this.metadata);

  Uri mainUri;
  Metadata metadata;
  Completer<CompilationResponse> result;
}

class CompilationResponse {
  final String? compilerOutput;
  final int errorCount;
  final Uri? kernelOutputUri;

  CompilationResponse(
      {this.compilerOutput, this.errorCount = 0, this.kernelOutputUri});
}

class TestCompiler {
  TestCompiler(this._dillCachePath)
      : _outputDillDirectory =
            Directory.systemTemp.createTempSync('dart_test.') {
    _outputDill = File(p.join(_outputDillDirectory.path, 'output.dill'));
    _compilerController.stream.listen(_onCompilationRequest);
  }

  final String _dillCachePath;
  final Directory _outputDillDirectory;
  final _compilerController = StreamController<_CompilationRequest>();
  final _compilationQueue = <_CompilationRequest>[];

  late final File _outputDill;
  FrontendServerClient? _frontendServerClient;

  Future<CompilationResponse> compile(Uri mainDart, Metadata metadata) {
    final completer = Completer<CompilationResponse>();
    if (_compilerController.isClosed) {
      return Future.value(null);
    }
    _compilerController.add(_CompilationRequest(mainDart, completer, metadata));
    return completer.future;
  }

  Future<void> dispose() async {
    await _compilerController.close();
    _frontendServerClient?.kill();
    _frontendServerClient = null;
    _outputDillDirectory.deleteSync(recursive: true);
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

  // Handle a compilation request.
  Future<void> _onCompilationRequest(_CompilationRequest request) async {
    final isEmpty = _compilationQueue.isEmpty;
    _compilationQueue.add(request);
    if (!isEmpty) {
      return;
    }
    while (_compilationQueue.isNotEmpty) {
      final request = _compilationQueue.first;
      var firstCompile = false;
      CompileResult? compilerOutput;
      final contents =
          await _generateEntrypoint(request.mainUri, request.metadata);
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
        request.result.complete(CompilationResponse(
            compilerOutput: compilerOutput?.compilerOutputLines.join('\n'),
            errorCount: compilerOutput?.errorCount ?? 0));
      } else {
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
        request.result.complete(CompilationResponse(
            compilerOutput: compilerOutput?.compilerOutputLines.join('\n'),
            errorCount: compilerOutput?.errorCount ?? 0,
            kernelOutputUri: kernelReadyToRun.absolute.uri));
        client.accept();
        client.reset();
      }
      _compilationQueue.removeAt(0);
    }
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
    );
    return client.compile();
  }
}
