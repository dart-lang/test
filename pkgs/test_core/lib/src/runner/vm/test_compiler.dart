// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.9

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:test_api/backend.dart'; // ignore: deprecated_member_use

/// A request to the [TestCompiler] for recompilation.
class _CompilationRequest {
  _CompilationRequest(this.mainUri, this.result, this.metadata);

  Uri mainUri;
  Metadata metadata;
  Completer<String> result;
}

class TestCompiler {
  TestCompiler(this._dillCachePath)
      : _outputDillDirectory =
            Directory.systemTemp.createTempSync('dart_test.') {
    _outputDill = File(path.join(_outputDillDirectory.path, 'output.dill'));
    _compilerController.stream.listen(_onCompilationRequest, onDone: () {
      _outputDillDirectory.deleteSync(recursive: true);
    });
  }

  final String _dillCachePath;
  final Directory _outputDillDirectory;
  final _compilerController = StreamController<_CompilationRequest>();
  final _compilationQueue = <_CompilationRequest>[];
  final _stdoutHandler = _StdoutHandler();

  File _outputDill;
  Process _compiler;
  PackageConfig _packageConfig;

  Future<String> compile(Uri mainDart, Metadata metadata) {
    final completer = Completer<String>();
    if (_compilerController.isClosed) {
      return Future.value(null);
    }
    _compilerController.add(_CompilationRequest(mainDart, completer, metadata));
    return completer.future;
  }

  Future<void> _shutdown() async {
    if (_compiler != null) {
      _compiler.kill();
      _compiler = null;
    }
  }

  Future<void> dispose() async {
    await _compilerController.close();
    await _shutdown();
  }

  Future<String> _languageVersionComment(Uri testUri) async {
    var localPackageConfig = _packageConfig ??= await loadPackageConfig(File(
        path.join(
            Directory.current.path, '.dart_tool', 'package_config.json')));
    var package = localPackageConfig.packageOf(testUri);
    if (package == null) {
      return '';
    }
    return '// @dart=${package.languageVersion.major}.${package.languageVersion.minor}';
  }

  Future<String> _generateEntrypoint(
      Uri testUri, Metadata suiteMetadata) async {
    return '''
        ${suiteMetadata.languageVersionComment ?? await _languageVersionComment(testUri)}
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
      _CompilerOutput compilerOutput;
      final contents =
          await _generateEntrypoint(request.mainUri, request.metadata);
      final tempFile = File(path.join(_outputDillDirectory.path, 'test.dart'))
        ..writeAsStringSync(contents);

      if (_compiler == null) {
        compilerOutput = await _createCompiler(tempFile.uri);
        firstCompile = true;
      } else {
        compilerOutput = await _recompile(
          tempFile.uri,
        );
      }
      final outputPath = compilerOutput?.outputFilename;
      if (outputPath == null || compilerOutput.errorCount > 0) {
        request.result.complete(null);
        await _shutdown();
      } else {
        final outputFile = File(outputPath);
        final kernelReadyToRun = await outputFile.copy('${tempFile.path}.dill');
        final testCache = File(_dillCachePath);
        if (firstCompile ||
            !testCache.existsSync() ||
            (testCache.lengthSync() < outputFile.lengthSync())) {
          // Keep the cache file up-to-date and include as many packages as possible,
          // using the kernel size as an approximation.
          if (!testCache.parent.existsSync()) {
            testCache.parent.createSync(recursive: true);
          }
          await outputFile.copy(_dillCachePath);
        }
        request.result.complete(kernelReadyToRun.absolute.path);
        _accept();
        _reset();
      }
      _compilationQueue.removeAt(0);
    }
  }

  String _generateInputKey(math.Random random) {
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(25) + 65;
    }
    return String.fromCharCodes(bytes);
  }

  Future<_CompilerOutput> _recompile(Uri mainUri) {
    _stdoutHandler.reset();
    final inputKey = _generateInputKey(math.Random());
    _compiler.stdin.writeln('recompile $mainUri $inputKey');
    _compiler.stdin.writeln('$mainUri');
    _compiler.stdin.writeln('$inputKey');
    return _stdoutHandler.compilerOutput.future;
  }

  void _accept() {
    _compiler.stdin.writeln('accept');
  }

  void _reset() {
    _compiler.stdin.writeln('reset');
    _stdoutHandler.reset(expectSources: false);
  }

  Future<_CompilerOutput> _createCompiler(Uri testUri) async {
    final frontendServer = path.normalize(path.join(Platform.resolvedExecutable,
        '..', 'snapshots', 'frontend_server.dart.snapshot'));
    final sdkRoot = Directory(
            path.relative(path.join(Platform.resolvedExecutable, '..', '..')))
        .uri;
    final platformDill = 'lib/_internal/vm_platform_strong.dill';
    final process = await Process.start(Platform.resolvedExecutable, <String>[
      '--disable-dart-dev',
      frontendServer,
      '--incremental',
      '--sdk-root=$sdkRoot',
      '--no-print-incremental-dependencies',
      '--target=vm',
      '--output-dill=${_outputDill.path}',
      '--initialize-from-dill=$_dillCachePath',
      '--platform=$platformDill',
      '--packages=${path.join(Directory.current.path, '.packages')}'
    ]);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_stdoutHandler.handler);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(print);
    process.stdin.writeln('compile $testUri');
    _compiler = process;
    return _stdoutHandler.compilerOutput.future;
  }
}

enum _StdoutState { CollectDiagnostic, CollectDependencies }

class _CompilerOutput {
  const _CompilerOutput(this.outputFilename, this.errorCount, this.sources);

  final String outputFilename;
  final int errorCount;
  final List<Uri> sources;
}

class _StdoutHandler {
  String boundaryKey;
  _StdoutState state = _StdoutState.CollectDiagnostic;
  Completer<_CompilerOutput> compilerOutput = Completer<_CompilerOutput>();
  final sources = <Uri>[];

  bool _suppressCompilerMessages = false;
  bool _expectSources = true;

  void handler(String message) {
    const kResultPrefix = 'result ';
    if (boundaryKey == null && message.startsWith(kResultPrefix)) {
      boundaryKey = message.substring(kResultPrefix.length);
      return;
    }
    if (message.startsWith(boundaryKey)) {
      if (_expectSources) {
        if (state == _StdoutState.CollectDiagnostic) {
          state = _StdoutState.CollectDependencies;
          return;
        }
      }
      if (message.length <= boundaryKey.length) {
        compilerOutput.complete(null);
        return;
      }
      final spaceDelimiter = message.lastIndexOf(' ');
      compilerOutput.complete(_CompilerOutput(
          message.substring(boundaryKey.length + 1, spaceDelimiter),
          int.parse(message.substring(spaceDelimiter + 1).trim()),
          sources));
      return;
    }
    if (state == _StdoutState.CollectDiagnostic) {
      if (!_suppressCompilerMessages) {
        print(message);
      }
    } else {
      assert(state == _StdoutState.CollectDependencies);
      switch (message[0]) {
        case '+':
          sources.add(Uri.parse(message.substring(1)));
          break;
        case '-':
          sources.remove(Uri.parse(message.substring(1)));
          break;
        default:
      }
    }
  }

  // This is needed to get ready to process next compilation result output,
  // with its own boundary key and new completer.
  void reset(
      {bool suppressCompilerMessages = false, bool expectSources = true}) {
    boundaryKey = null;
    compilerOutput = Completer<_CompilerOutput>();
    _suppressCompilerMessages = suppressCompilerMessages;
    _expectSources = expectSources;
    state = _StdoutState.CollectDiagnostic;
  }
}
