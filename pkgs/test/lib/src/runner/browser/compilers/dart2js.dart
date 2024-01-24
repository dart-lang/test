// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http_multi_server/http_multi_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_packages_handler/shelf_packages_handler.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test_api/backend.dart' show StackTraceMapper, SuitePlatform;
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/dart2js_compiler_pool.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/package_version.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/io.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/package_config.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../util/math.dart';
import '../../../util/one_off_handler.dart';
import '../../../util/package_map.dart';
import '../../../util/path_handler.dart';
import 'compiler_support.dart';

/// Support for Dart2Js compiled tests.
class Dart2JsSupport extends CompilerSupport with JsHtmlWrapper {
  /// Whether [close] has been called.
  bool _closed = false;

  /// The temporary directory in which compiled JS is emitted.
  final _compiledDir = createTempDir();

  /// A map from test suite paths to Futures that will complete once those
  /// suites are finished compiling.
  ///
  /// This is used to make sure that a given test suite is only compiled once
  /// per run, rather than once per browser per run.
  final _compileFutures = <String, Future<void>>{};

  /// The [Dart2JsCompilerPool] managing active instances of `dart2js`.
  final _compilerPool = Dart2JsCompilerPool();

  /// Mappers for Dartifying stack traces, indexed by test path.
  final _mappers = <String, StackTraceMapper>{};

  /// A [PathHandler] used to serve test specific artifacts.
  final _pathHandler = PathHandler();

  /// The root directory served statically by this server.
  final String _root;

  /// Each compiler serves its tests under a different randomly-generated
  /// secret URI to ensure that other users on the same system can't snoop
  /// on data being served through this server, as well as distinguish tests
  /// from different compilers from each other.
  final String _secret = randomUrlSecret();

  /// The underlying server.
  final shelf.Server _server;

  /// A [OneOffHandler] for servicing WebSocket connections for
  /// [BrowserManager]s.
  ///
  /// This is one-off because each [BrowserManager] can only connect to a single
  /// WebSocket.
  final _webSocketHandler = OneOffHandler();

  @override
  Uri get serverUrl => _server.url.resolve('$_secret/');

  Dart2JsSupport._(super.config, super.defaultTemplatePath, this._server,
      this._root, String faviconPath) {
    var cascade = shelf.Cascade()
        .add(_webSocketHandler.handler)
        .add(packagesDirHandler())
        .add(_pathHandler.handler)
        .add(createStaticHandler(_root))
        .add(htmlWrapperHandler);

    var pipeline = const shelf.Pipeline()
        .addMiddleware(PathHandler.nestedIn(_secret))
        .addHandler(cascade.handler);

    _server.mount(shelf.Cascade()
        .add(createFileHandler(faviconPath))
        .add(pipeline)
        .handler);
  }

  static Future<Dart2JsSupport> start({
    required Configuration config,
    required String defaultTemplatePath,
    required String root,
    required String faviconPath,
  }) async {
    var server = shelf_io.IOServer(await HttpMultiServer.loopback(0));
    return Dart2JsSupport._(
        config, defaultTemplatePath, server, root, faviconPath);
  }

  @override
  Future<void> compileSuite(
      String dartPath, SuiteConfiguration suiteConfig, SuitePlatform platform) {
    return _compileFutures.putIfAbsent(dartPath, () async {
      var dir = Directory(_compiledDir).createTempSync('test_').path;
      var jsPath = p.join(dir, '${p.basename(dartPath)}.browser_test.dart.js');
      var bootstrapContent = '''
        ${suiteConfig.metadata.languageVersionComment ?? await rootPackageLanguageVersionComment}
        import 'package:test/src/bootstrap/browser.dart';
        import 'package:test/src/runner/browser/dom.dart' as dom;

        import '${await absoluteUri(dartPath)}' as test;

        void main() {
          dom.window.console.log(r'Startup for test path $dartPath');
          internalBootstrapBrowserTest(() => test.main);
        }
      ''';

      await _compilerPool.compile(bootstrapContent, jsPath, suiteConfig);
      if (_closed) return;

      var bootstrapUrl = '${p.toUri(p.relative(dartPath, from: _root)).path}'
          '.browser_test.dart';
      _pathHandler.add(bootstrapUrl, (request) {
        return shelf.Response.ok(bootstrapContent,
            headers: {'Content-Type': 'application/dart'});
      });

      var jsUrl = '${p.toUri(p.relative(dartPath, from: _root)).path}'
          '.browser_test.dart.js';
      _pathHandler.add(jsUrl, (request) {
        return shelf.Response.ok(File(jsPath).readAsStringSync(),
            headers: {'Content-Type': 'application/javascript'});
      });

      var mapUrl = '${p.toUri(p.relative(dartPath, from: _root)).path}'
          '.browser_test.dart.js.map';
      _pathHandler.add(mapUrl, (request) {
        return shelf.Response.ok(File('$jsPath.map').readAsStringSync(),
            headers: {'Content-Type': 'application/json'});
      });

      if (suiteConfig.jsTrace) return;
      var mapPath = '$jsPath.map';
      _mappers[dartPath] = JSStackTraceMapper(File(mapPath).readAsStringSync(),
          mapUrl: p.toUri(mapPath),
          sdkRoot: Uri.parse('org-dartlang-sdk:///sdk'),
          packageMap: (await currentPackageConfig).toPackageMap());
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([
      Directory(_compiledDir).deleteWithRetry(),
      _compilerPool.close(),
      _server.close(),
    ]);
  }

  @override
  StackTraceMapper? stackTraceMapperForPath(String dartPath) =>
      _mappers[dartPath];

  @override
  (Uri, Future<WebSocketChannel>) get webSocket {
    var completer = Completer<WebSocketChannel>.sync();
    var path = _webSocketHandler.create(webSocketHandler(completer.complete));
    var webSocketUrl = serverUrl.replace(scheme: 'ws').resolve(path);
    return (webSocketUrl, completer.future);
  }
}
