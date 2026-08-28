// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:test_api/backend.dart'
    show Compiler, Runtime, SuitePlatform, debugTimestamp;
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/load_exception.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/customizable_platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/runner_suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/package_config.dart'; // ignore: implementation_imports
import 'package:yaml/yaml.dart';

import '../executable_settings.dart';
import 'browser_manager.dart';
import 'compilers/compiler_support.dart';
import 'compilers/dart2js.dart';
import 'compilers/dart2wasm.dart';
import 'compilers/precompiled.dart';
import 'default_settings.dart';

class BrowserPlatform extends PlatformPlugin
    implements CustomizablePlatform<ExecutableSettings> {
  /// Starts the server.
  ///
  /// [root] is the root directory that the server should serve. It defaults to
  /// the working directory.
  static Future<BrowserPlatform> start({String? root}) async {
    var packageConfig = await currentPackageConfig;
    return BrowserPlatform._(
      Configuration.current,
      p.fromUri(
        packageConfig.resolve(
          Uri.parse('package:test/src/runner/browser/static/favicon.ico'),
        ),
      ),
      p.fromUri(
        packageConfig.resolve(
          Uri.parse('package:test/src/runner/browser/static/default.html.tpl'),
        ),
      ),
      p.fromUri(
        packageConfig.resolve(
          Uri.parse(
            'package:test/src/runner/browser/static/run_wasm_chrome.js',
          ),
        ),
      ),
      root: root,
    );
  }

  /// The test runner configuration.
  final Configuration _config;

  /// The cached [CompilerSupport] for each compiler.
  final _compilerSupport = <Compiler, Future<CompilerSupport>>{};

  /// The `package:test` side wrapper for the Dart2Wasm runtime.
  final String _jsRuntimeWrapper;

  /// The URL for this server and [compiler] combination.
  ///
  /// Each compiler serves its tests under a different randomly-generated
  /// secret URI to ensure that other users on the same system can't snoop
  /// on data being served through this server, as well as distinguish tests
  /// from different compilers from each other.
  Future<CompilerSupport> compilerSupport(Compiler compiler) =>
      _compilerSupport.putIfAbsent(compiler, () {
        if (_config.suiteDefaults.precompiledPath != null) {
          return PrecompiledSupport.start(
            compiler: compiler,
            config: _config,
            defaultTemplatePath: _defaultTemplatePath,
            root: _config.suiteDefaults.precompiledPath!,
            faviconPath: _faviconPath,
          );
        }
        return switch (compiler) {
          Compiler.dart2js => Dart2JsSupport.start(
            config: _config,
            defaultTemplatePath: _defaultTemplatePath,
            root: _root,
            faviconPath: _faviconPath,
          ),
          Compiler.dart2wasm => Dart2WasmSupport.start(
            config: _config,
            defaultTemplatePath: _defaultTemplatePath,
            jsRuntimeWrapper: _jsRuntimeWrapper,
            root: _root,
            faviconPath: _faviconPath,
          ),
          _ => throw StateError('Unexpected compiler $compiler'),
        };
      });

  /// The root directory served statically by this server.
  final String _root;

  /// Whether [close] has been called.
  bool get _closed => _closeMemo.hasRun;

  /// A map from browser identifiers to futures that will complete to the
  /// [BrowserManager]s for those browsers, or `null` if they failed to load.
  ///
  /// This should only be accessed through [_browserManagerFor].
  final _browserManagers = <(Runtime, Compiler), Future<BrowserManager?>>{};

  /// Settings for invoking each browser.
  ///
  /// This starts out with the default settings, which may be overridden by user settings.
  final _browserSettings = Map<Runtime, ExecutableSettings>.from(
    defaultSettings,
  );

  /// The default template for html tests.
  final String _defaultTemplatePath;

  final String _faviconPath;

  BrowserPlatform._(
    Configuration config,
    this._faviconPath,
    this._defaultTemplatePath,
    this._jsRuntimeWrapper, {
    String? root,
  }) : _config = config,
       _root = root ?? p.current;

  @override
  ExecutableSettings parsePlatformSettings(YamlMap settings) =>
      ExecutableSettings.parse(settings);

  @override
  ExecutableSettings mergePlatformSettings(
    ExecutableSettings settings1,
    ExecutableSettings settings2,
  ) => settings1.merge(settings2);

  @override
  void customizePlatform(Runtime runtime, ExecutableSettings settings) {
    var oldSettings =
        _browserSettings[runtime] ?? _browserSettings[runtime.root];
    if (oldSettings != null) settings = oldSettings.merge(settings);
    _browserSettings[runtime] = settings;
  }

  /// Loads the test suite at [path] on the platform [platform].
  ///
  /// This will start a browser to load the suite if one isn't already running.
  /// Throws an [ArgumentError] if `platform.platform` isn't a browser.
  @override
  Future<RunnerSuite?> load(
    String path,
    SuitePlatform platform,
    SuiteConfiguration suiteConfig,
    Map<String, Object?> message,
  ) async {
    var browser = platform.runtime;
    print(
      '[DEBUG-BROWSER-PLATFORM] BrowserPlatform.load started for $path on ${browser.name} (${platform.compiler.name})',
    );
    assert(suiteConfig.runtimes.contains(browser.identifier));

    if (!browser.isBrowser) {
      throw ArgumentError('$browser is not a browser.');
    }

    var compiler = platform.compiler;
    print(
      '[DEBUG-BROWSER-PLATFORM] Getting compilerSupport for ${compiler.name}',
    );
    var support = await compilerSupport(compiler);

    var htmlPathFromTestPath = '${p.withoutExtension(path)}.html';
    if (File(htmlPathFromTestPath).existsSync()) {
      if (_config.customHtmlTemplatePath != null &&
          p.basename(htmlPathFromTestPath) ==
              p.basename(_config.customHtmlTemplatePath!)) {
        throw LoadException(
          path,
          'template file "${p.basename(_config.customHtmlTemplatePath!)}" cannot be named '
          'like the test file.',
        );
      }
      _checkHtmlCorrectness(htmlPathFromTestPath, path);
    } else if (_config.customHtmlTemplatePath != null) {
      var htmlTemplatePath = _config.customHtmlTemplatePath!;
      if (!File(htmlTemplatePath).existsSync()) {
        throw LoadException(
          path,
          '"$htmlTemplatePath" does not exist or is not readable',
        );
      }

      final templateFileContents = File(htmlTemplatePath).readAsStringSync();
      if ('{{testScript}}'.allMatches(templateFileContents).length != 1) {
        throw LoadException(
          path,
          '"$htmlTemplatePath" must contain exactly one {{testScript}} placeholder',
        );
      }
      _checkHtmlCorrectness(htmlTemplatePath, path);
    }

    if (_closed) {
      print(
        '[DEBUG-BROWSER-PLATFORM] BrowserPlatform closed before compileSuite for $path',
      );
      return null;
    }
    print(
      '[DEBUG-BROWSER-PLATFORM] Compiling suite for $path with ${compiler.name}',
    );
    await support.compileSuite(path, suiteConfig, platform);
    print(
      '[DEBUG-BROWSER-PLATFORM] Compiled suite for $path with ${compiler.name}',
    );

    var suiteUrl = support.serverUrl.resolveUri(
      p.toUri('${p.withoutExtension(p.relative(path, from: _root))}.html'),
    );

    if (_closed) {
      print(
        '[DEBUG-BROWSER-PLATFORM] BrowserPlatform closed before _browserManagerFor for $path',
      );
      return null;
    }

    print(
      '[DEBUG-BROWSER-PLATFORM] Getting browser manager for (${browser.name}, ${compiler.name})',
    );
    var browserManager = await _browserManagerFor(browser, compiler);
    if (_closed || browserManager == null) {
      print(
        '[DEBUG-BROWSER-PLATFORM] Closed or browserManager is null for $path',
      );
      return null;
    }

    var timeout = const Duration(seconds: 30);
    if (suiteConfig.metadata.timeout.apply(timeout) case final suiteTimeout?
        when suiteTimeout > timeout) {
      timeout = suiteTimeout;
    }
    print('[DEBUG-BROWSER-PLATFORM] Calling browserManager.load for $path');
    var suite = await browserManager.load(
      path,
      suiteUrl,
      suiteConfig,
      message,
      platform.compiler,
      mapper: (await compilerSupport(compiler)).stackTraceMapperForPath(path),
      timeout: timeout,
    );
    print(
      '[DEBUG-BROWSER-PLATFORM] browserManager.load returned suite=$suite for $path',
    );
    if (_closed) return null;
    return suite;
  }

  void _checkHtmlCorrectness(String htmlPath, String path) {
    if (!File(htmlPath).readAsStringSync().contains('packages/test/dart.js')) {
      throw LoadException(
        path,
        '"$htmlPath" must contain <script src="packages/test/dart.js">'
        '</script>.',
      );
    }
  }

  /// Returns the [BrowserManager] for [runtime], which should be a browser.
  ///
  /// If no browser manager is running yet, starts one.
  Future<BrowserManager?> _browserManagerFor(
    Runtime browser,
    Compiler compiler,
  ) {
    var managerFuture = _browserManagers[(browser, compiler)];
    if (managerFuture != null) return managerFuture;

    var future = _createBrowserManager(browser, compiler);
    // Store null values for browsers that error out so we know not to load them
    // again.
    _browserManagers[(browser, compiler)] = future
        .then<BrowserManager?>((value) => value)
        .onError((_, _) => null);

    return future;
  }

  Future<BrowserManager> _createBrowserManager(
    Runtime browser,
    Compiler compiler,
  ) async {
    var support = await compilerSupport(compiler);
    var (webSocketUrl, socketFuture) = support.webSocket;
    var hostUrl = support.serverUrl
        .resolve('packages/test/src/runner/browser/static/index.html')
        .replace(
          queryParameters: {
            'managerUrl': webSocketUrl.toString(),
            'debug': _config.debug.toString(),
          },
        );

    return BrowserManager.start(
      browser,
      hostUrl,
      socketFuture,
      _browserSettings[browser]!,
      _config,
    );
  }

  /// Close all the browsers that the server currently has open.
  ///
  /// Note that this doesn't close the server itself. Browser tests can still be
  /// loaded, they'll just spawn new browsers.
  @override
  Future<List<void>> closeEphemeral() {
    print(
      '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] BrowserPlatform.closeEphemeral started (${_browserManagers.length} managers)',
    );
    var managers = _browserManagers.values.toList();
    _browserManagers.clear();
    return Future.wait(
      managers.map((manager) async {
        var result = await manager;
        if (result == null) return;
        print(
          '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] Calling manager.close in closeEphemeral for $result',
        );
        await result.close();
        print(
          '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] manager.close completed in closeEphemeral for $result',
        );
      }),
    ).then((val) {
      print(
        '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] BrowserPlatform.closeEphemeral finished',
      );
      return val;
    });
  }

  /// Closes the server and releases all its resources.
  ///
  /// Returns a [Future] that completes once the server is closed and its
  /// resources have been fully released.
  @override
  Future<void> close() async => _closeMemo.runOnce(
    () {
      print(
        '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] BrowserPlatform.close started',
      );
      return Future.wait([
        for (var browser in _browserManagers.values)
          browser.then((b) async {
            print(
              '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] Closing browser manager $b in BrowserPlatform.close',
            );
            await b?.close();
            print(
              '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] Browser manager $b closed in BrowserPlatform.close',
            );
          }),
        for (var support in _compilerSupport.values)
          support.then((s) async {
            print(
              '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] Closing compilerSupport $s in BrowserPlatform.close',
            );
            await s.close();
            print(
              '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] CompilerSupport $s closed in BrowserPlatform.close',
            );
          }),
      ]).then((_) {
        print(
          '[DEBUG-BROWSER-PLATFORM] [${debugTimestamp()}] BrowserPlatform.close finished',
        );
      });
    },
  );
  final _closeMemo = AsyncMemoizer<void>();
}
