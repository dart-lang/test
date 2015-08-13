// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../../backend/metadata.dart';
import '../../backend/suite.dart';
import '../../backend/test_platform.dart';
import '../../util/io.dart';
import '../../util/one_off_handler.dart';
import '../../util/path_handler.dart';
import '../../util/stack_trace_mapper.dart';
import '../../utils.dart';
import '../configuration.dart';
import '../load_exception.dart';
import 'browser_manager.dart';
import 'compiler_pool.dart';
import 'polymer.dart';

/// A server that serves JS-compiled tests to browsers.
///
/// A test suite may be loaded for a given file using [loadSuite].
class BrowserServer {
  /// Starts the server.
  ///
  /// [root] is the root directory that the server should serve. It defaults to
  /// the working directory.
  static Future<BrowserServer> start(Configuration config, {String root})
      async {
    var server = new BrowserServer._(root, config);
    await server._load();
    return server;
  }

  /// The underlying HTTP server.
  HttpServer _server;

  /// A randomly-generated secret.
  ///
  /// This is used to ensure that other users on the same system can't snoop
  /// on data being served through this server.
  final _secret = randomBase64(24, urlSafe: true);

  /// The URL for this server.
  Uri get url => baseUrlForAddress(_server.address, _server.port)
      .resolve(_secret + "/");

  /// The test runner configuration.
  Configuration _config;

  /// A [OneOffHandler] for servicing WebSocket connections for
  /// [BrowserManager]s.
  ///
  /// This is one-off because each [BrowserManager] can only connect to a single
  /// WebSocket,
  final _webSocketHandler = new OneOffHandler();

  /// A [PathHandler] used to serve compiled JS.
  final _jsHandler = new PathHandler();

  /// The [CompilerPool] managing active instances of `dart2js`.
  ///
  /// This is `null` if tests are loaded from `pub serve`.
  final CompilerPool _compilers;

  /// The temporary directory in which compiled JS is emitted.
  final String _compiledDir;

  /// The root directory served statically by this server.
  final String _root;

  /// The pool of active `pub serve` compilations.
  ///
  /// Pub itself ensures that only one compilation runs at a time; we just use
  /// this pool to make sure that the output is nice and linear.
  final _pubServePool = new Pool(1);

  /// The HTTP client to use when caching JS files in `pub serve`.
  final HttpClient _http;

  /// Whether [close] has been called.
  bool get _closed => _closeMemo.hasRun;

  /// The memoizer for running [close] exactly once.
  final _closeMemo = new AsyncMemoizer();

  /// A map from browser identifiers to futures that will complete to the
  /// [BrowserManager]s for those browsers, or the errors that occurred when
  /// trying to load those managers.
  ///
  /// This should only be accessed through [_browserManagerFor].
  final _browserManagers =
      new Map<TestPlatform, Future<Result<BrowserManager>>>();

  /// A map from test suite paths to Futures that will complete once those
  /// suites are finished compiling.
  ///
  /// This is used to make sure that a given test suite is only compiled once
  /// per run, rather than once per browser per run.
  final _compileFutures = new Map<String, Future>();

  final _mappers = new Map<String, StackTraceMapper>();

  BrowserServer._(String root, Configuration config)
      : _root = root == null ? p.current : root,
        _config = config,
        _compiledDir = config.pubServeUrl == null ? createTempDir() : null,
        _http = config.pubServeUrl == null ? null : new HttpClient(),
        _compilers = new CompilerPool(color: config.color);

  /// Starts the underlying server.
  Future _load() async {
    var cascade = new shelf.Cascade()
        .add(_webSocketHandler.handler);

    if (_config.pubServeUrl == null) {
      cascade = cascade
          .add(_createPackagesHandler())
          .add(_jsHandler.handler)
          .add(createStaticHandler(_root))
          .add(_wrapperHandler);
    }

    var pipeline = new shelf.Pipeline()
      .addMiddleware(nestingMiddleware(_secret))
      .addHandler(cascade.handler);

    _server = await HttpMultiServer.loopback(0);
    shelf_io.serveRequests(_server, pipeline);
  }

  /// Returns a handler that serves the contents of the "packages/" directory
  /// for any URL that contains "packages/".
  ///
  /// This is a factory so it can wrap a static handler.
  shelf.Handler _createPackagesHandler() {
    var staticHandler =
      createStaticHandler(_config.packageRoot, serveFilesOutsidePath: true);

    return (request) {
      var segments = p.url.split(request.url.path);

      for (var i = 0; i < segments.length; i++) {
        if (segments[i] != "packages") continue;
        return staticHandler(
            request.change(path: p.url.joinAll(segments.take(i + 1))));
      }

      return new shelf.Response.notFound("Not found.");
    };
  }

  /// A handler that serves wrapper files used to bootstrap tests.
  shelf.Response _wrapperHandler(shelf.Request request) {
    var path = p.fromUri(request.url);

    if (path.endsWith(".browser_test.dart")) {
      return new shelf.Response.ok('''
import "package:test/src/runner/browser/iframe_listener.dart";

import "${p.basename(p.withoutExtension(p.withoutExtension(path)))}" as test;

void main() {
  IframeListener.start(() => test.main);
}
''', headers: {'Content-Type': 'application/dart'});
    }

    if (path.endsWith(".html")) {
      var test = p.withoutExtension(path) + ".dart";

      // Link to the Dart wrapper on Dartium and the compiled JS version
      // elsewhere.
      var scriptBase =
          "${HTML_ESCAPE.convert(p.basename(test))}.browser_test.dart";
      var script = request.headers['user-agent'].contains('(Dart)')
          ? 'type="application/dart" src="$scriptBase"'
          : 'src="$scriptBase.js"';

      return new shelf.Response.ok('''
<!DOCTYPE html>
<html>
<head>
  <title>${HTML_ESCAPE.convert(test)} Test</title>
  <script $script></script>
</head>
</html>
''', headers: {'Content-Type': 'text/html'});
    }

    return new shelf.Response.notFound('Not found.');
  }

  /// Loads the test suite at [path] on the browser [browser].
  ///
  /// This will start a browser to load the suite if one isn't already running.
  /// Throws an [ArgumentError] if [browser] isn't a browser platform.
  Future<Suite> loadSuite(String path, TestPlatform browser,
      Metadata metadata) async {
    if (!browser.isBrowser) {
      throw new ArgumentError("$browser is not a browser.");
    }

    var htmlPath = p.withoutExtension(path) + '.html';
    if (new File(htmlPath).existsSync() &&
        !new File(htmlPath).readAsStringSync()
            .contains('packages/test/dart.js')) {
      throw new LoadException(
          path,
          '"${htmlPath}" must contain <script src="packages/test/dart.js">'
              '</script>.');
    }

    var suiteUrl;
    if (_config.pubServeUrl != null) {
      var suitePrefix = p.withoutExtension(
          p.relative(path, from: p.join(_root, 'test')));

      var jsUrl;
      // Polymer generates a bootstrap entrypoint that wraps the entrypoint we
      // see on disk, and modifies the HTML file to point to the bootstrap
      // instead. To make sure we get the right source maps and wait for the
      // right file to compile, we have some Polymer-specific logic here to load
      // the boostrap instead of the unwrapped file.
      if (isPolymerEntrypoint(path)) {
        jsUrl = _config.pubServeUrl.resolve(
            "$suitePrefix.html.polymer.bootstrap.dart.browser_test.dart.js");
      } else {
        jsUrl = _config.pubServeUrl.resolve(
          '$suitePrefix.dart.browser_test.dart.js');
      }

      await _pubServeSuite(path, jsUrl);
      suiteUrl = _config.pubServeUrl.resolveUri(p.toUri('$suitePrefix.html'));
    } else {
      if (browser.isJS) await _compileSuite(path);
      if (_closed) return null;
      suiteUrl = url.resolveUri(p.toUri(
          p.withoutExtension(p.relative(path, from: _root)) + ".html"));
    }

    if (_closed) return null;

    // TODO(nweiz): Don't start the browser until all the suites are compiled.
    var browserManager = await _browserManagerFor(browser);
    if (_closed) return null;

    var suite = await browserManager.loadSuite(path, suiteUrl, metadata,
        mapper: browser.isJS ? _mappers[path] : null);
    if (_closed) return null;
    return suite;
  }

  /// Loads a test suite at [path] from the `pub serve` URL [jsUrl].
  ///
  /// This ensures that only one suite is loaded at a time, and that any errors
  /// are exposed as [LoadException]s.
  Future _pubServeSuite(String path, Uri jsUrl) {
    return _pubServePool.withResource(() async {
      var timer = new Timer(new Duration(seconds: 1), () {
        print('"pub serve" is compiling $path...');
      });

      var mapUrl = jsUrl.replace(path: jsUrl.path + '.map');
      var response;
      try {
        // Get the source map here for two reasons. We want to verify that the
        // server's dart2js compiler is running on the Dart code, and also load
        // the StackTraceMapper.
        var request = await _http.getUrl(mapUrl);
        response = await request.close();

        if (response.statusCode != 200) {
          // We don't care about the response body, but we have to drain it or
          // else the process can't exit.
          response.listen((_) {});

          throw new LoadException(path,
              "Error getting $mapUrl: ${response.statusCode} "
                  "${response.reasonPhrase}\n"
              'Make sure "pub serve" is serving the test/ directory.');
        }

        if (_config.jsTrace) {
          // Drain the response stream.
          response.listen((_) {});
          return;
        }

        _mappers[path] = new StackTraceMapper(
            await UTF8.decodeStream(response),
            mapUrl: mapUrl,
            packageRoot: _config.pubServeUrl.resolve('packages'),
            sdkRoot: _config.pubServeUrl.resolve('packages/\$sdk'));
      } on IOException catch (error) {
        var message = getErrorMessage(error);
        if (error is SocketException) {
          message = "${error.osError.message} "
              "(errno ${error.osError.errorCode})";
        }

        throw new LoadException(path,
            "Error getting $mapUrl: $message\n"
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
  Future _compileSuite(String dartPath) {
    return _compileFutures.putIfAbsent(dartPath, () async {
      var dir = new Directory(_compiledDir).createTempSync('test_').path;
      var jsPath = p.join(dir, p.basename(dartPath) + ".js");

      await _compilers.compile(dartPath, jsPath,
          packageRoot: _config.packageRoot);
      if (_closed) return;

      var jsUrl = p.toUri(p.relative(dartPath, from: _root)).path +
          '.browser_test.dart.js';
      _jsHandler.add(jsUrl, (request) {
        return new shelf.Response.ok(new File(jsPath).readAsStringSync(),
            headers: {'Content-Type': 'application/javascript'});
      });

      var mapUrl = p.toUri(p.relative(dartPath, from: _root)).path +
          '.browser_test.dart.js.map';
      _jsHandler.add(mapUrl, (request) {
        return new shelf.Response.ok(
            new File(jsPath + '.map').readAsStringSync(),
            headers: {'Content-Type': 'application/json'});
      });

      if (_config.jsTrace) return;
      var mapPath = jsPath + '.map';
      _mappers[dartPath] = new StackTraceMapper(
          new File(mapPath).readAsStringSync(),
          mapUrl: p.toUri(mapPath),
          packageRoot: p.toUri(_config.packageRoot),
          sdkRoot: p.toUri(sdkDir));
    });
  }

  /// Returns the [BrowserManager] for [platform], which should be a browser.
  ///
  /// If no browser manager is running yet, starts one.
  Future<BrowserManager> _browserManagerFor(TestPlatform platform) {
    var manager = _browserManagers[platform];
    if (manager != null) return Result.release(manager);

    var completer = new Completer.sync();
    var path = _webSocketHandler.create(webSocketHandler(completer.complete));
    var webSocketUrl = url.replace(scheme: 'ws').resolve(path);
    var hostUrl = (_config.pubServeUrl == null ? url : _config.pubServeUrl)
        .resolve('packages/test/src/runner/browser/static/index.html')
        .replace(queryParameters: {'managerUrl': webSocketUrl.toString()});

    var future = BrowserManager.start(platform, hostUrl, completer.future,
        debug: _config.pauseAfterLoad);

    // Capture errors and release them later to avoid Zone issues. This call to
    // [_browserManagerFor] is running in a different [LoadSuite] than future
    // calls, which means they're also running in different error zones so
    // errors can't be freely passed between them. Storing the error or value as
    // an explicit [Result] fixes that.
    _browserManagers[platform] = Result.capture(future);

    return future;
  }

  /// Closes the server and releases all its resources.
  ///
  /// Returns a [Future] that completes once the server is closed and its
  /// resources have been fully released.
  Future close() {
    return _closeMemo.runOnce(() async {
      var futures = _browserManagers.values.map((future) async {
        var result = await future;
        if (result.isError) return;

        await result.asValue.value.close();
      }).toList();

      futures.add(_server.close());
      futures.add(_compilers.close());

      await Future.wait(futures);

      if (_config.pubServeUrl == null) {
        new Directory(_compiledDir).deleteSync(recursive: true);
      } else {
        _http.close();
      }
    });
  }
}
