// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_packages_handler/shelf_packages_handler.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yaml/yaml.dart';

import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/runner_suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/utils.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports

import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/compiler_pool.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/load_exception.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/customizable_platform.dart'; // ignore: implementation_imports

import '../executable_settings.dart';
import '../../util/path_handler.dart';
import '../../util/one_off_handler.dart';
import 'browser_manager.dart';
import 'default_settings.dart';

class BrowserPlatform extends PlatformPlugin
    implements CustomizablePlatform<ExecutableSettings> {
  /// Starts the server.
  ///
  /// [root] is the root directory that the server should serve. It defaults to
  /// the working directory.
  static Future<BrowserPlatform> start({String root}) async {
    var server = shelf_io.IOServer(await HttpMultiServer.loopback(0));
    return BrowserPlatform._(
        server,
        Configuration.current,
        p.fromUri(await Isolate.resolvePackageUri(
            Uri.parse('package:test/src/runner/browser/static/favicon.ico'))),
        root: root);
  }

  /// The test runner configuration.
  final Configuration _config;

  /// The underlying server.
  final shelf.Server _server;

  /// A randomly-generated secret.
  ///
  /// This is used to ensure that other users on the same system can't snoop
  /// on data being served through this server.
  final _secret = Uri.encodeComponent(randomBase64(24));

  /// The URL for this server.
  Uri get url => _server.url.resolve(_secret + "/");

  /// A [OneOffHandler] for servicing WebSocket connections for
  /// [BrowserManager]s.
  ///
  /// This is one-off because each [BrowserManager] can only connect to a single
  /// WebSocket,
  final _webSocketHandler = OneOffHandler();

  /// A [PathHandler] used to serve compiled JS.
  final _jsHandler = PathHandler();

  /// The [CompilerPool] managing active instances of `dart2js`.
  final _compilers = CompilerPool();

  /// The temporary directory in which compiled JS is emitted.
  final String _compiledDir;

  /// The root directory served statically by this server.
  final String _root;

  /// The pool of active `pub serve` compilations.
  ///
  /// Pub itself ensures that only one compilation runs at a time; we just use
  /// this pool to make sure that the output is nice and linear.
  final _pubServePool = Pool(1);

  /// The HTTP client to use when caching JS files in `pub serve`.
  final HttpClient _http;

  /// Whether [close] has been called.
  bool get _closed => _closeMemo.hasRun;

  /// A map from browser identifiers to futures that will complete to the
  /// [BrowserManager]s for those browsers, or `null` if they failed to load.
  ///
  /// This should only be accessed through [_browserManagerFor].
  final _browserManagers = <Runtime, Future<BrowserManager>>{};

  /// Settings for invoking each browser.
  ///
  /// This starts out with the default settings, which may be overridden by user settings.
  final _browserSettings =
      Map<Runtime, ExecutableSettings>.from(defaultSettings);

  /// A map from test suite paths to Futures that will complete once those
  /// suites are finished compiling.
  ///
  /// This is used to make sure that a given test suite is only compiled once
  /// per run, rather than once per browser per run.
  final _compileFutures = Map<String, Future>();

  /// Mappers for Dartifying stack traces, indexed by test path.
  final _mappers = Map<String, StackTraceMapper>();

  BrowserPlatform._(this._server, Configuration config, String faviconPath,
      {String root})
      : _config = config,
        _root = root == null ? p.current : root,
        _compiledDir = config.pubServeUrl == null ? createTempDir() : null,
        _http = config.pubServeUrl == null ? null : HttpClient() {
    var cascade = shelf.Cascade().add(_webSocketHandler.handler);

    if (_config.pubServeUrl == null) {
      cascade = cascade
          .add(packagesDirHandler())
          .add(_jsHandler.handler)
          .add(createStaticHandler(
              config.suiteDefaults.precompiledPath ?? _root,
              // Precompiled directories often contain symlinks
              serveFilesOutsidePath:
                  config.suiteDefaults.precompiledPath != null))
          .add(_wrapperHandler);
    }

    var pipeline = shelf.Pipeline()
        .addMiddleware(PathHandler.nestedIn(_secret))
        .addHandler(cascade.handler);

    _server.mount(shelf.Cascade()
        .add(createFileHandler(faviconPath))
        .add(pipeline)
        .handler);
  }

  /// A handler that serves wrapper files used to bootstrap tests.
  shelf.Response _wrapperHandler(shelf.Request request) {
    var path = p.fromUri(request.url);

    if (path.endsWith(".browser_test.dart")) {
      var testPath = p.basename(p.withoutExtension(p.withoutExtension(path)));
      return shelf.Response.ok('''
        import "package:stream_channel/stream_channel.dart";

        import "package:test_core/src/runner/plugin/remote_platform_helpers.dart";
        import "package:test/src/runner/browser/post_message_channel.dart";

        import "$testPath" as test;

        void main() {
          var channel = serializeSuite(() => test.main, hidePrints: false);
          postMessageChannel().pipe(channel);
        }
      ''', headers: {'Content-Type': 'application/dart'});
    }

    if (path.endsWith(".html")) {
      var test = p.withoutExtension(path) + ".dart";

      // Link to the Dart wrapper on Dartium and the compiled JS version
      // elsewhere.
      var scriptBase = htmlEscape.convert(p.basename(test));
      var link = '<link rel="x-dart-test" href="$scriptBase">';

      return shelf.Response.ok('''
        <!DOCTYPE html>
        <html>
        <head>
          <title>${htmlEscape.convert(test)} Test</title>
          $link
          <script src="packages/test/dart.js"></script>
        </head>
        </html>
      ''', headers: {'Content-Type': 'text/html'});
    }

    return shelf.Response.notFound('Not found.');
  }

  ExecutableSettings parsePlatformSettings(YamlMap settings) =>
      ExecutableSettings.parse(settings);

  ExecutableSettings mergePlatformSettings(
          ExecutableSettings settings1, ExecutableSettings settings2) =>
      settings1.merge(settings2);

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
  Future<RunnerSuite> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Object message) async {
    var browser = platform.runtime;
    assert(suiteConfig.runtimes.contains(browser.identifier));

    if (!browser.isBrowser) {
      throw ArgumentError("$browser is not a browser.");
    }

    var htmlPath = p.withoutExtension(path) + '.html';
    if (File(htmlPath).existsSync() &&
        !File(htmlPath).readAsStringSync().contains('packages/test/dart.js')) {
      throw LoadException(
          path,
          '"${htmlPath}" must contain <script src="packages/test/dart.js">'
          '</script>.');
    }

    Uri suiteUrl;
    if (_config.pubServeUrl != null) {
      var suitePrefix = p
          .toUri(
              p.withoutExtension(p.relative(path, from: p.join(_root, 'test'))))
          .path;

      var dartUrl =
          _config.pubServeUrl.resolve('$suitePrefix.dart.browser_test.dart');

      await _pubServeSuite(path, dartUrl, browser, suiteConfig);
      suiteUrl = _config.pubServeUrl.resolveUri(p.toUri('$suitePrefix.html'));
    } else {
      if (browser.isJS) {
        if (suiteConfig.precompiledPath == null) {
          await _compileSuite(path, suiteConfig);
        }
      }

      if (_closed) return null;
      suiteUrl = url.resolveUri(
          p.toUri(p.withoutExtension(p.relative(path, from: _root)) + ".html"));
    }

    if (_closed) return null;

    // TODO(nweiz): Don't start the browser until all the suites are compiled.
    var browserManager = await _browserManagerFor(browser);
    if (_closed || browserManager == null) return null;

    var suite = await browserManager.load(path, suiteUrl, suiteConfig, message,
        mapper: browser.isJS ? _mappers[path] : null);
    if (_closed) return null;
    return suite;
  }

  StreamChannel loadChannel(String path, SuitePlatform platform) =>
      throw UnimplementedError();

  /// Loads a test suite at [path] from the `pub serve` URL [dartUrl].
  ///
  /// This ensures that only one suite is loaded at a time, and that any errors
  /// are exposed as [LoadException]s.
  Future _pubServeSuite(String path, Uri dartUrl, Runtime browser,
      SuiteConfiguration suiteConfig) {
    return _pubServePool.withResource(() async {
      var timer = Timer(Duration(seconds: 1), () {
        print('"pub serve" is compiling $path...');
      });

      // For browsers that run Dart compiled to JavaScript, get the source map
      // instead of the Dart code for two reasons. We want to verify that the
      // server's dart2js compiler is running on the Dart code, and also load
      // the StackTraceMapper.
      var getSourceMap = browser.isJS;

      var url = getSourceMap
          ? dartUrl.replace(path: dartUrl.path + '.js.map')
          : dartUrl;

      HttpClientResponse response;
      try {
        var request = await _http.getUrl(url);
        response = await request.close();

        if (response.statusCode != 200) {
          // We don't care about the response body, but we have to drain it or
          // else the process can't exit.
          response.listen((_) {});

          throw LoadException(
              path,
              "Error getting $url: ${response.statusCode} "
              "${response.reasonPhrase}\n"
              'Make sure "pub serve" is serving the test/ directory.');
        }

        if (getSourceMap && !suiteConfig.jsTrace) {
          _mappers[path] = JSStackTraceMapper(await utf8.decodeStream(response),
              mapUrl: url,
              packageResolver: SyncPackageResolver.root('packages'),
              sdkRoot: p.toUri('packages/\$sdk'));
          return;
        }

        // Drain the response stream.
        response.listen((_) {});
      } on IOException catch (error) {
        var message = getErrorMessage(error);
        if (error is SocketException) {
          message = "${error.osError.message} "
              "(errno ${error.osError.errorCode})";
        }

        throw LoadException(
            path,
            "Error getting $url: $message\n"
            'Make sure "pub serve" is running.');
      } finally {
        timer.cancel();
      }
    });
  }

  /// Compile the test suite at [dartPath] to JavaScript.
  ///
  /// Once the suite has been compiled, it's added to [_jsHandler] so it can be
  /// served.
  Future _compileSuite(String dartPath, SuiteConfiguration suiteConfig) {
    return _compileFutures.putIfAbsent(dartPath, () async {
      var dir = Directory(_compiledDir).createTempSync('test_').path;
      var jsPath = p.join(dir, p.basename(dartPath) + ".browser_test.dart.js");

      await _compilers.compile('''
        import "package:test/src/bootstrap/browser.dart";

        import "${p.toUri(p.absolute(dartPath))}" as test;

        void main() {
          internalBootstrapBrowserTest(() => test.main);
        }
      ''', jsPath, suiteConfig);
      if (_closed) return;

      var jsUrl = p.toUri(p.relative(dartPath, from: _root)).path +
          '.browser_test.dart.js';
      _jsHandler.add(jsUrl, (request) {
        return shelf.Response.ok(File(jsPath).readAsStringSync(),
            headers: {'Content-Type': 'application/javascript'});
      });

      var mapUrl = p.toUri(p.relative(dartPath, from: _root)).path +
          '.browser_test.dart.js.map';
      _jsHandler.add(mapUrl, (request) {
        return shelf.Response.ok(File(jsPath + '.map').readAsStringSync(),
            headers: {'Content-Type': 'application/json'});
      });

      if (suiteConfig.jsTrace) return;
      var mapPath = jsPath + '.map';
      _mappers[dartPath] = JSStackTraceMapper(File(mapPath).readAsStringSync(),
          mapUrl: p.toUri(mapPath),
          packageResolver: await PackageResolver.current.asSync,
          sdkRoot: p.toUri(sdkDir));
    });
  }

  /// Returns the [BrowserManager] for [runtime], which should be a browser.
  ///
  /// If no browser manager is running yet, starts one.
  Future<BrowserManager> _browserManagerFor(Runtime browser) {
    var managerFuture = _browserManagers[browser];
    if (managerFuture != null) return managerFuture;

    var completer = Completer<WebSocketChannel>.sync();
    var path = _webSocketHandler.create(webSocketHandler(completer.complete));
    var webSocketUrl = url.replace(scheme: 'ws').resolve(path);
    var hostUrl = (_config.pubServeUrl == null ? url : _config.pubServeUrl)
        .resolve('packages/test/src/runner/browser/static/index.html')
        .replace(queryParameters: {
      'managerUrl': webSocketUrl.toString(),
      'debug': _config.pauseAfterLoad.toString()
    });

    var future = BrowserManager.start(
        browser, hostUrl, completer.future, _browserSettings[browser],
        debug: _config.pauseAfterLoad);

    // Store null values for browsers that error out so we know not to load them
    // again.
    _browserManagers[browser] = future.catchError((_) => null);

    return future;
  }

  /// Close all the browsers that the server currently has open.
  ///
  /// Note that this doesn't close the server itself. Browser tests can still be
  /// loaded, they'll just spawn new browsers.
  Future closeEphemeral() {
    var managers = _browserManagers.values.toList();
    _browserManagers.clear();
    return Future.wait(managers.map((manager) async {
      var result = await manager;
      if (result == null) return;
      await result.close();
    }));
  }

  /// Closes the server and releases all its resources.
  ///
  /// Returns a [Future] that completes once the server is closed and its
  /// resources have been fully released.
  Future close() => _closeMemo.runOnce(() async {
        var futures =
            _browserManagers.values.map<Future<dynamic>>((future) async {
          var result = await future;
          if (result == null) return;

          await result.close();
        }).toList();

        futures.add(_server.close());
        futures.add(_compilers.close());

        await Future.wait(futures);

        if (_config.pubServeUrl == null) {
          Directory(_compiledDir).deleteSync(recursive: true);
        } else {
          _http.close();
        }
      });
  final _closeMemo = AsyncMemoizer();
}
