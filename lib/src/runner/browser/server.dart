// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import '../../util/path_handler.dart';
import '../../util/one_off_handler.dart';
import '../../utils.dart';
import '../load_exception.dart';
import 'browser.dart';
import 'browser_manager.dart';
import 'compiler_pool.dart';
import 'chrome.dart';
import 'dartium.dart';
import 'content_shell.dart';
import 'firefox.dart';
import 'phantom_js.dart';
import 'safari.dart';

/// A server that serves JS-compiled tests to browsers.
///
/// A test suite may be loaded for a given file using [loadSuite].
class BrowserServer {
  /// Starts the server.
  ///
  /// [root] is the root directory that the server should serve. It defaults to
  /// the working directory.
  ///
  /// If [packageRoot] is passed, it's used for all package imports when
  /// compiling tests to JS. Otherwise, the package root is inferred from
  /// [root].
  ///
  /// If [pubServeUrl] is passed, tests will be loaded from the `pub serve`
  /// instance at that URL rather than from the filesystem.
  ///
  /// If [color] is true, console colors will be used when compiling Dart.
  ///
  /// If the package root doesn't exist, throws an [ApplicationException].
  static Future<BrowserServer> start({String root, String packageRoot,
      Uri pubServeUrl, bool color: false}) {
    var server = new BrowserServer._(root, packageRoot, pubServeUrl, color);
    return server._load().then((_) => server);
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

  /// The package root.
  final String _packageRoot;

  /// The URL for the `pub serve` instance to use to load tests.
  ///
  /// This is `null` if tests should be compiled manually.
  final Uri _pubServeUrl;

  /// The pool of active `pub serve` compilations.
  ///
  /// Pub itself ensures that only one compilation runs at a time; we just use
  /// this pool to make sure that the output is nice and linear.
  final _pubServePool = new Pool(1);

  /// The HTTP client to use when caching JS files in `pub serve`.
  final HttpClient _http;

  /// Whether [close] has been called.
  bool get _closed => _closeCompleter != null;

  /// The completer for the [Future] returned by [close].
  Completer _closeCompleter;

  /// All currently-running browsers.
  ///
  /// These are controlled by [_browserManager]s.
  final _browsers = new Map<TestPlatform, Browser>();

  /// A map from browser identifiers to futures that will complete to the
  /// [BrowserManager]s for those browsers.
  ///
  /// This should only be accessed through [_browserManagerFor].
  final _browserManagers = new Map<TestPlatform, Future<BrowserManager>>();

  /// A map from test suite paths to Futures that will complete once those
  /// suites are finished compiling.
  ///
  /// This is used to make sure that a given test suite is only compiled once
  /// per run, rather than one per browser per run.
  final _compileFutures = new Map<String, Future>();

  BrowserServer._(String root, String packageRoot, Uri pubServeUrl, bool color)
      : _root = root == null ? p.current : root,
        _packageRoot = packageRootFor(root, packageRoot),
        _pubServeUrl = pubServeUrl,
        _compiledDir = pubServeUrl == null ? createTempDir() : null,
        _http = pubServeUrl == null ? null : new HttpClient(),
        _compilers = new CompilerPool(color: color);

  /// Starts the underlying server.
  Future _load() {
    var cascade = new shelf.Cascade()
        .add(_webSocketHandler.handler);

    if (_pubServeUrl == null) {
      cascade = cascade
          .add(_createPackagesHandler())
          .add(_jsHandler.handler)
          .add(_wrapperHandler)
          .add(createStaticHandler(_root));
    }

    var pipeline = new shelf.Pipeline()
      .addMiddleware(nestingMiddleware(_secret))
      .addHandler(cascade.handler);

    return shelf_io.serve(pipeline, 'localhost', 0).then((server) {
      _server = server;
    });
  }

  /// Returns a handler that serves the contents of the "packages/" directory
  /// for any URL that contains "packages/".
  ///
  /// This is a factory so it can wrap a static handler.
  shelf.Handler _createPackagesHandler() {
    var staticHandler =
      createStaticHandler(_packageRoot, serveFilesOutsidePath: true);

    return (request) {
      var segments = p.url.split(shelfUrl(request).path);

      for (var i = 0; i < segments.length; i++) {
        if (segments[i] != "packages") continue;
        return staticHandler(
            shelfChange(request, path: p.url.joinAll(segments.take(i + 1))));
      }

      return new shelf.Response.notFound("Not found.");
    };
  }

  /// A handler that serves wrapper files used to bootstrap tests.
  shelf.Response _wrapperHandler(shelf.Request request) {
    var path = p.fromUri(shelfUrl(request));
    var withoutExtensions = p.withoutExtension(p.withoutExtension(path));
    var base = p.basename(withoutExtensions);

    if (path.endsWith(".browser_test.dart")) {
      return new shelf.Response.ok('''
import "package:test/src/runner/browser/iframe_listener.dart";

import "$base" as test;

void main() {
  IframeListener.start(() => test.main);
}
''', headers: {'Content-Type': 'application/dart'});
    }

    if (path.endsWith(".browser_test.html")) {
      // TODO(nweiz): support user-authored HTML files.
      return new shelf.Response.ok('''
<!DOCTYPE html>
<html>
<head>
  <title>${HTML_ESCAPE.convert(base)}.dart Test</title>
  <script type="application/dart"
          src="${HTML_ESCAPE.convert(base)}.browser_test.dart">
  </script>
  <script src="packages/browser/dart.js"></script>
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
      Metadata metadata) {
    if (!browser.isBrowser) {
      throw new ArgumentError("$browser is not a browser.");
    }

    return new Future.sync(() {
      if (_pubServeUrl != null) {
        var suitePrefix = p.relative(path, from: p.join(_root, 'test')) +
            '.browser_test';
        var jsUrl = _pubServeUrl.resolve('$suitePrefix.dart.js');
        return _pubServeSuite(path, jsUrl).then((_) =>
            _pubServeUrl.resolve('$suitePrefix.html'));
      }

      return new Future.sync(() => browser.isJS ? _compileSuite(path) : null)
          .then((_) {
        if (_closed) return null;
        return url.resolveUri(
            p.toUri(p.relative(path, from: _root) + ".browser_test.html"));
      });
    }).then((suiteUrl) {
      if (_closed) return null;

      // TODO(nweiz): Don't start the browser until all the suites are compiled.
      return _browserManagerFor(browser).then((browserManager) {
        if (_closed) return null;
        return browserManager.loadSuite(path, suiteUrl, metadata);
      }).then((suite) {
        if (_closed) return null;
        if (suite != null) return suite.change(platform: browser.name);

        // If the browser manager fails to load a suite and the server isn't
        // closed, it's probably because the browser failed. We emit the failure
        // here to ensure that it gets surfaced.
        return _browsers[browser].onExit;
      });
    });
  }

  /// Loads a test suite at [path] from the `pub serve` URL [jsUrl].
  ///
  /// This ensures that only one suite is loaded at a time, and that any errors
  /// are exposed as [LoadException]s.
  Future _pubServeSuite(String path, Uri jsUrl) {
    return _pubServePool.withResource(() {
      var timer = new Timer(new Duration(seconds: 1), () {
        print('"pub serve" is compiling $path...');
      });

      return _http.headUrl(jsUrl)
          .then((request) => request.close())
          .whenComplete(timer.cancel)
          .catchError((error, stackTrace) {
        if (error is! IOException) throw error;

        var message = getErrorMessage(error);
        if (error is SocketException) {
          message = "${error.osError.message} "
              "(errno ${error.osError.errorCode})";
        }

        throw new LoadException(path,
            "Error getting $jsUrl: $message\n"
            'Make sure "pub serve" is running.');
      }).then((response) {
        if (response.statusCode == 200) return;

        throw new LoadException(path,
            "Error getting $jsUrl: ${response.statusCode} "
                "${response.reasonPhrase}\n"
            'Make sure "pub serve" is serving the test/ directory.');
      });
    });
  }

  /// Compile the test suite at [dartPath] to JavaScript.
  ///
  /// Once the suite has been compiled, it's added to [_jsHandler] so it can be
  /// served.
  Future _compileSuite(String dartPath) {
    return _compileFutures.putIfAbsent(dartPath, () {
      var dir = new Directory(_compiledDir).createTempSync('test_').path;
      var jsPath = p.join(dir, p.basename(dartPath) + ".js");

      return _compilers.compile(dartPath, jsPath, packageRoot: _packageRoot)
          .then((_) {
        if (_closed) return;

        _jsHandler.add(
            p.relative(dartPath, from: _root) + '.browser_test.dart.js',
            (request) {
          return new shelf.Response.ok(new File(jsPath).readAsStringSync(),
              headers: {'Content-Type': 'application/javascript'});
        });
      });
    });
  }

  /// Returns the [BrowserManager] for [platform], which should be a browser.
  ///
  /// If no browser manager is running yet, starts one.
  Future<BrowserManager> _browserManagerFor(TestPlatform platform) {
    var manager = _browserManagers[platform];
    if (manager != null) return manager;

    var completer = new Completer();

    // Swallow errors, since they're already being surfaced through the return
    // value and [browser.onError].
    _browserManagers[platform] = completer.future.catchError((_) {});
    var path = _webSocketHandler.create(webSocketHandler((webSocket) {
      completer.complete(new BrowserManager(webSocket));
    }));

    var webSocketUrl = url.replace(scheme: 'ws').resolve(path);

    var hostUrl = (_pubServeUrl == null ? url : _pubServeUrl)
        .resolve('packages/test/src/runner/browser/static/index.html');

    var browser = _newBrowser(hostUrl.replace(queryParameters: {
      'managerUrl': webSocketUrl.toString()
    }), platform);
    _browsers[platform] = browser;

    // TODO(nweiz): Gracefully handle the browser being killed before the
    // tests complete.
    browser.onExit.catchError((error, stackTrace) {
      if (completer.isCompleted) return;
      completer.completeError(error, stackTrace);
    });

    return completer.future;
  }

  /// Starts the browser identified by [browser] and has it load [url].
  Browser _newBrowser(Uri url, TestPlatform browser) {
    switch (browser) {
      case TestPlatform.dartium: return new Dartium(url);
      case TestPlatform.contentShell: return new ContentShell(url);
      case TestPlatform.chrome: return new Chrome(url);
      case TestPlatform.phantomJS: return new PhantomJS(url);
      case TestPlatform.firefox: return new Firefox(url);
      case TestPlatform.safari: return new Safari(url);
      default:
        throw new ArgumentError("$browser is not a browser.");
    }
  }

  /// Closes the server and releases all its resources.
  ///
  /// Returns a [Future] that completes once the server is closed and its
  /// resources have been fully released.
  Future close() {
    if (_closeCompleter != null) return _closeCompleter.future;
    _closeCompleter = new Completer();

    return Future.wait([
      _server.close(),
      _compilers.close()
    ]).then((_) {
      if (_browserManagers.isEmpty) return null;
      return Future.wait(_browserManagers.keys.map((platform) {
        return _browserManagers[platform]
            .then((_) => _browsers[platform].close());
      }));
    }).then((_) {
      if (_pubServeUrl == null) {
        new Directory(_compiledDir).deleteSync(recursive: true);
      } else {
        _http.close();
      }

      _closeCompleter.complete();
    }).catchError(_closeCompleter.completeError);
  }
}
