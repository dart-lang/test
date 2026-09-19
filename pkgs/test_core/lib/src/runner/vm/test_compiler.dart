// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:frontend_server_client/frontend_server_client.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:test_api/backend.dart';

import '../../util/dart.dart';
import '../../util/io.dart';
import '../../util/package_config.dart';
import '../package_version.dart';

class CompilationResponse {
  final String? compilerOutput;
  final int errorCount;
  final Uri? kernelOutputUri;

  const CompilationResponse({
    this.compilerOutput,
    this.errorCount = 0,
    this.kernelOutputUri,
  });

  static const _wasShutdown = CompilationResponse(
    errorCount: 1,
    compilerOutput: 'Compiler no longer active.',
  );
}

class TestCompiler {
  final _closeMemo = AsyncMemoizer<void>();

  /// Each language version that appears in test files gets its own compiler,
  /// to ensure that all language modes are supported (such as sound and
  /// unsound null safety).
  final _compilerForLanguageVersion =
      <String, _TestCompilerForLanguageVersion>{};

  /// The compiler which produced each outstanding kernel file, keyed by the
  /// `kernelOutputUri` that was handed out for it.
  final _compilerForKernelOutput = <Uri, _TestCompilerForLanguageVersion>{};

  /// A prefix used for the dill files for each compiler that is created.
  final String _dillCachePrefix;

  final FrontendClientFactory _clientFactory;

  /// No work is done until the first call to [compile] is received, at which
  /// point the compiler process is started.
  TestCompiler(
    this._dillCachePrefix, {
    FrontendClientFactory clientFactory = FrontendServerClient.start,
  }) : _clientFactory = clientFactory;

  /// Compiles [mainDart], using a separate compiler per language version of
  /// the tests.
  ///
  /// Each successful compilation creates a new kernel file which is retained
  /// until either [release] is called with the returned
  /// [CompilationResponse.kernelOutputUri], or this compiler is disposed.
  Future<CompilationResponse> compile(Uri mainDart, Metadata metadata) async {
    if (_closeMemo.hasRun) return CompilationResponse._wasShutdown;
    var languageVersionComment =
        metadata.languageVersionComment ??
        await rootPackageLanguageVersionComment;
    var compiler = _compilerForLanguageVersion.putIfAbsent(
      languageVersionComment,
      () => _TestCompilerForLanguageVersion(
        _dillCachePrefix,
        languageVersionComment,
        _clientFactory,
      ),
    );
    var response = await compiler.compile(mainDart);
    if (response.kernelOutputUri case var kernelOutputUri?) {
      _compilerForKernelOutput[kernelOutputUri] = compiler;
    }
    return response;
  }

  /// Indicates that the kernel file at [kernelOutputUri] is no longer in use.
  ///
  /// The [kernelOutputUri] must be a [CompilationResponse.kernelOutputUri]
  /// returned by a previous call to [compile], and it must not be used after
  /// it has been released since the file may be deleted.
  ///
  /// Releasing kernel files as soon as their test suite has finished keeps the
  /// temporary disk usage of a test run from growing with the number of test
  /// suites.
  Future<void> release(Uri kernelOutputUri) async {
    if (_closeMemo.hasRun) return;
    await _compilerForKernelOutput
        .remove(kernelOutputUri)
        ?.release(kernelOutputUri);
  }

  Future<void> dispose() => _closeMemo.runOnce(() async {
    _compilerForKernelOutput.clear();
    await Future.wait([
      for (var compiler in _compilerForLanguageVersion.values)
        compiler.dispose(),
    ]);
  });
}

class _TestCompilerForLanguageVersion {
  final _closeMemo = AsyncMemoizer<void>();
  final _compilePool = Pool(1);
  final String _dillCachePath;
  final FrontendClientFactory _clientFactory;
  FrontendServerClient? _frontendServerClient;
  final String _languageVersionComment;
  late final _outputDill = File(
    p.join(_outputDillDirectory.path, 'output.dill'),
  );
  final _outputDillDirectory = Directory.systemTemp.createTempSync(
    'dart_test.kernel.',
  );
  // Used to create unique file names for final kernel files.
  int _compileNumber = 0;
  // The largest incremental dill file we created, will be cached under
  // the `.dart_tool` dir at the end of compilation.
  //
  // This file is kept even after it has been released, until either a larger
  // dill file replaces it or the compiler is disposed.
  File? _dillToCache;
  // Whether [_dillToCache] has been released by the code that requested it, in
  // which case it can be deleted as soon as it is replaced.
  bool _dillToCacheIsReleased = false;

  _TestCompilerForLanguageVersion(
    String dillCachePrefix,
    this._languageVersionComment,
    this._clientFactory,
  ) : _dillCachePath =
          '$dillCachePrefix.'
          '${_dillCacheSuffix(_languageVersionComment, enabledExperiments)}';

  Future<CompilationResponse> compile(Uri mainUri) =>
      _compilePool.withResource(() => _compile(mainUri));

  Future<CompilationResponse> _compile(Uri mainUri) async {
    _compileNumber++;
    if (_closeMemo.hasRun) return CompilationResponse._wasShutdown;
    CompileResult? compilerOutput;
    final tempFile = File(p.join(_outputDillDirectory.path, 'test.dart'))
      ..writeAsStringSync(
        testBootstrapContents(
          testUri: mainUri,
          packageConfigUri: await packageConfigUri,
          languageVersionComment: _languageVersionComment,
          testType: VmTestType.isolate,
        ),
      );
    final testCache = File(_dillCachePath);

    try {
      if (_frontendServerClient case final frontendServerClient?) {
        compilerOutput = await frontendServerClient.compile(<Uri>[
          tempFile.uri,
        ]);
      } else {
        if (await testCache.exists()) {
          await testCache.copy(_outputDill.path);
        }
        compilerOutput = await _createCompiler(tempFile.uri);
        if (_closeMemo.hasRun) return CompilationResponse._wasShutdown;
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
        errorCount: compilerOutput?.errorCount ?? 0,
      );
    }

    final outputFile = File(outputPath);
    final kernelReadyToRun = await outputFile.copy(
      '${tempFile.path}_$_compileNumber.dill',
    );
    // Keep the `_dillToCache` file up-to-date and use the size of the
    // kernel file as an approximation for how many packages are included.
    // Larger files are preferred, since re-using more packages will reduce the
    // number of files the frontend server needs to load and parse.
    final previousDillToCache = _dillToCache;
    if (previousDillToCache == null ||
        (previousDillToCache.lengthSync() < kernelReadyToRun.lengthSync())) {
      _dillToCache = kernelReadyToRun;
      if (previousDillToCache != null && _dillToCacheIsReleased) {
        await _tryDelete(previousDillToCache);
      }
      _dillToCacheIsReleased = false;
    }

    return CompilationResponse(
      compilerOutput: compilerOutput?.compilerOutputLines.join('\n'),
      errorCount: compilerOutput?.errorCount ?? 0,
      kernelOutputUri: kernelReadyToRun.absolute.uri,
    );
  }

  Future<CompileResult?> _createCompiler(Uri testUri) async {
    final platformDill = 'lib/_internal/vm_platform_strong.dill';
    final sdkRoot = p.relative(
      p.dirname(p.dirname(Platform.resolvedExecutable)),
    );
    final packageConfigUriAwaited = await packageConfigUri;

    // If we have native assets for the host os in JIT mode, they are either
    // in the `.dart_tool/` in the root package or in the pub workspace.
    Uri? nativeAssetsYaml;
    final nativeAssetsYamlRootPackage = Directory.current.uri.resolve(
      '.dart_tool/native_assets.yaml',
    );
    final nativeAssetsYamlWorkspace = packageConfigUriAwaited.resolve(
      'native_assets.yaml',
    );
    for (final potentialNativeAssetsUri in [
      nativeAssetsYamlRootPackage,
      nativeAssetsYamlWorkspace,
    ]) {
      if (await File.fromUri(potentialNativeAssetsUri).exists()) {
        nativeAssetsYaml = potentialNativeAssetsUri;
        break;
      }
    }

    var client = await _clientFactory(
      testUri.toString(),
      _outputDill.path,
      platformDill,
      enabledExperiments: enabledExperiments,
      sdkRoot: sdkRoot,
      packagesJson: packageConfigUriAwaited.toFilePath(),
      nativeAssets: nativeAssetsYaml?.toFilePath(),
      printIncrementalDependencies: false,
    );

    if (_closeMemo.hasRun) {
      client.kill();
      return null;
    }

    _frontendServerClient = client;
    return client.compile();
  }

  /// Deletes the kernel file at [kernelOutputUri], unless it is being kept as
  /// the candidate to cache under the `.dart_tool` dir.
  Future<void> release(Uri kernelOutputUri) async {
    if (_closeMemo.hasRun) return;
    final file = File.fromUri(kernelOutputUri);
    if (_dillToCache case final dillToCache?
        when p.equals(dillToCache.path, file.path)) {
      _dillToCacheIsReleased = true;
      return;
    }
    await _tryDelete(file);
  }

  /// Deletes [file], ignoring any failure to do so.
  ///
  /// The file may still be held open, for instance by an isolate which has not
  /// finished shutting down. Anything left behind is cleaned up along with the
  /// temp directory in [dispose].
  Future<void> _tryDelete(File file) async {
    try {
      await file.deleteWithRetry();
    } on FileSystemException {
      // Ignore, this file will be deleted with the temp directory.
    }
  }

  Future<void> dispose() => _closeMemo.runOnce(() async {
    _frontendServerClient?.kill();
    _frontendServerClient = null;
    await _compilePool.close();
    if (_dillToCache != null) {
      var testCache = File(_dillCachePath);
      if (!testCache.parent.existsSync()) {
        testCache.parent.createSync(recursive: true);
      }
      _dillToCache!.copySync(_dillCachePath);
    }
    if (_outputDillDirectory.existsSync()) {
      await _outputDillDirectory.deleteWithRetry();
    }
  });
}

typedef FrontendClientFactory =
    Future<FrontendServerClient> Function(
      String entrypoint,
      String outputDillPath,
      String platformKernel, {
      List<String>? enabledExperiments,
      bool printIncrementalDependencies,
      String sdkRoot,
      String packagesJson,
      String? nativeAssets,
    });

/// Computes a unique dill cache suffix for each [languageVersionComment]
/// and [enabledExperiments] combination.
String _dillCacheSuffix(
  String languageVersionComment,
  List<String> enabledExperiments,
) {
  var identifierString = StringBuffer(
    languageVersionComment.replaceAll(' ', ''),
  );
  for (var experiment in enabledExperiments) {
    identifierString.writeln(experiment);
  }
  return base64.encode(utf8.encode(identifierString.toString()));
}

/// Creates bootstrap file contents for running [testUri].
///
/// The [bootstrapType] argument should be either 'Vm' or 'Native' depending on
/// which `internalBootstrap*Test` function should be used.
String testBootstrapContents({
  required Uri testUri,
  required String languageVersionComment,
  required Uri packageConfigUri,
  required VmTestType testType,
}) {
  final (mainArgs, forwardedArgName, bootstrapType) = switch (testType) {
    VmTestType.isolate => ('_, SendPort sendPort', 'sendPort', 'Vm'),
    VmTestType.process => ('List<String> args', 'args', 'Native'),
  };
  return '''
    $languageVersionComment

    import 'dart:isolate';

    import 'package:test_core/src/bootstrap/vm.dart';

    import '$testUri' as test;

    // This variable is read at runtime through the VM service and is unsafe to
    // remove.
    const packageConfigLocation = '$packageConfigUri';

    void main($mainArgs) {
      internalBootstrap${bootstrapType}Test(() => test.main, $forwardedArgName);
    }
  ''';
}

enum VmTestType { isolate, process }
