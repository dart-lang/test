// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../../backend/suite.dart';
import '../../util/io.dart';
import '../../util/one_off_handler.dart';
import 'browser_manager.dart';
import 'compiler_pool.dart';
import 'chrome.dart';

/// A server that serves JS-compiled tests to browsers.
///
/// A test suite may be loaded for a given file using [loadSuite].
class BrowserServer {
  /// Starts the server.
  ///
  /// If [packageRoot] is passed, it's used for all package imports when
  /// compiling tests to JS. Otherwise, the package root is inferred from the
  /// location of the source file.
  ///
  /// If [color] is true, console colors will be used when compiling Dart.
  static Future<BrowserServer> start({String packageRoot, bool color: false}) {
    var server = new BrowserServer._(packageRoot, color);
    return server._load().then((_) => server);
  }

  /// The underlying HTTP server.
  HttpServer _server;

  /// The URL for this server.
  Uri get url => baseUrlForAddress(_server.address, _server.port);

  /// a [OneOffHandler] for servicing WebSocket connections for
  /// [BrowserManager]s.
  ///
  /// This is one-off because each [BrowserManager] can only connect to a single
  /// WebSocket,
  final _webSocketHandler = new OneOffHandler();

  /// The [CompilerPool] managing active instances of `dart2js`.
  final CompilerPool _compilers;

  /// The temporary directory in which compiled JS is emitted.
  final String _compiledDir;

  /// The package root which is passed to `dart2js`.
  final String _packageRoot;

  /// The browser in which test suites are loaded and run.
  ///
  /// This is `null` until a suite is loaded.
  Chrome _browser;

  /// A future that will complete to the [BrowserManager] for [_browser].
  ///
  /// The first time this is called, it will start both the browser and the
  /// browser manager. Any further calls will return the existing manager.
  Future<BrowserManager> get _browserManager {
    if (_browserManagerCompleter == null) {
      _browserManagerCompleter = new Completer();
      var path = _webSocketHandler.create(webSocketHandler((webSocket) {
        _browserManagerCompleter.complete(new BrowserManager(webSocket));
      }));

      var webSocketUrl = url.replace(scheme: 'ws', path: '/$path');
      _browser = new Chrome(url.replace(queryParameters: {
        'managerUrl': webSocketUrl.toString()
      }));

      // TODO(nweiz): Gracefully handle the browser being killed before the
      // tests complete.
      _browser.onExit.catchError((error, stackTrace) {
        if (_browserManagerCompleter.isCompleted) return;
        _browserManagerCompleter.completeError(error, stackTrace);
      });
    }
    return _browserManagerCompleter.future;
  }
  Completer<BrowserManager> _browserManagerCompleter;

  BrowserServer._(this._packageRoot, bool color)
      : _compiledDir = Directory.systemTemp.createTempSync('unittest_').path,
        _compilers = new CompilerPool(color: color);

  /// Starts the underlying server.
  Future _load() {
    var staticPath = p.join(libDir(packageRoot: _packageRoot),
        'src/runner/browser/static');
    var cascade = new shelf.Cascade()
        .add(_webSocketHandler.handler)
        .add(createStaticHandler(staticPath, defaultDocument: 'index.html'))
        .add(createStaticHandler(_compiledDir, defaultDocument: 'index.html'));

    return shelf_io.serve(cascade.handler, 'localhost', 0).then((server) {
      _server = server;
    });
  }

  /// Loads the test suite at [path].
  ///
  /// This will start a browser to load the suite if one isn't already running.
  Future<Suite> loadSuite(String path) {
    return _compileSuite(path).then((dir) {
      // TODO(nweiz): Don't start the browser until all the suites are compiled.
      return _browserManager.then((browserManager) {
        // Add a trailing slash because at least on Chrome, the iframe's
        // window.location.href will do so automatically, and if that differs
        // from the original URL communication will fail.
        var suiteUrl = url.resolve(
            "/" + p.toUri(p.relative(dir, from: _compiledDir)).path + "/");
        return browserManager.loadSuite(path, suiteUrl);
      });
    });
  }

  /// Compile the test suite at [dartPath] to JavaScript.
  ///
  /// Returns a [Future] that completes to the path to the JavaScript.
  Future<String> _compileSuite(String dartPath) {
    var dir = new Directory(_compiledDir).createTempSync('test_').path;
    var jsPath = p.join(dir, p.basename(dartPath) + ".js");
    return _compilers.compile(dartPath, jsPath,
            packageRoot: packageRootFor(dartPath, _packageRoot))
        .then((_) {
      // TODO(nweiz): support user-authored HTML files.
      new File(p.join(dir, "index.html")).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <title>${HTML_ESCAPE.convert(dartPath)} Test</title>
  <script src="${HTML_ESCAPE.convert(p.basename(jsPath))}"></script>
</head>
</html>
''');
      return dir;
    });
  }

  /// Closes the server and releases all its resources.
  ///
  /// Returns a [Future] that completes once the server is closed and its
  /// resources have been fully released.
  Future close() {
    new Directory(_compiledDir).deleteSync(recursive: true);
    return _server.close().then((_) {
      if (_browserManagerCompleter == null) return null;
      return _browserManager.then((_) => _browser.close());
    });
  }
}
