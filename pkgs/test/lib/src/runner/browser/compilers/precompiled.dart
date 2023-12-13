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
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/package_config.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../util/math.dart';
import '../../../util/one_off_handler.dart';
import '../../../util/package_map.dart';
import '../../../util/path_handler.dart';
import 'compiler_support.dart';

/// Support for precompiled test files.
class PrecompiledSupport implements CompilerSupport {
  /// Whether [close] has been called.
  bool _closed = false;

  /// Mappers for Dartifying stack traces, indexed by test path.
  final _mappers = <String, StackTraceMapper>{};

  /// A [PathHandler] used to serve test specific artifacts.
  final _pathHandler = PathHandler();

  /// The root directory served statically by the server.
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

  /// The URL at which this compiler serves its tests.
  ///
  /// Each compiler serves its tests under a different directory.
  @override
  Uri get serverUrl => _server.url.resolve('$_secret/');

  PrecompiledSupport._(this._server, this._root, String faviconPath) {
    var cascade = shelf.Cascade()
        .add(_webSocketHandler.handler)
        .add(packagesDirHandler())
        .add(_pathHandler.handler)
        .add(createStaticHandler(_root));

    var pipeline = const shelf.Pipeline()
        .addMiddleware(PathHandler.nestedIn(_secret))
        .addHandler(cascade.handler);

    _server.mount(shelf.Cascade()
        .add(createFileHandler(faviconPath))
        .add(pipeline)
        .handler);
  }

  static Future<PrecompiledSupport> start({
    required String root,
    required String faviconPath,
  }) async {
    var server = shelf_io.IOServer(await HttpMultiServer.loopback(0));
    return PrecompiledSupport._(server, root, faviconPath);
  }

  /// Compiles [dartPath] using [suiteConfig] for [platform].
  @override
  Future<void> compileSuite(String dartPath, SuiteConfiguration suiteConfig,
      SuitePlatform platform) async {
    if (suiteConfig.jsTrace) return;
    var mapPath = p.join(
        suiteConfig.precompiledPath!, '$dartPath.browser_test.dart.js.map');
    var mapFile = File(mapPath);
    if (mapFile.existsSync()) {
      _mappers[dartPath] = JSStackTraceMapper(mapFile.readAsStringSync(),
          mapUrl: p.toUri(mapPath),
          sdkRoot: Uri.parse(r'/packages/$sdk'),
          packageMap: (await currentPackageConfig).toPackageMap());
    }
  }

  /// Retrieves a stack trace mapper for [path] if available.
  @override
  StackTraceMapper? stackTraceMapperForPath(String dartPath) =>
      _mappers[dartPath];

  /// Closes down anything necessary for this implementation.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _server.close();
  }

  @override
  (Uri, Future<WebSocketChannel>) get webSocket {
    var completer = Completer<WebSocketChannel>.sync();
    var path = _webSocketHandler.create(webSocketHandler(completer.complete));
    var webSocketUrl = serverUrl.replace(scheme: 'ws').resolve(path);
    return (webSocketUrl, completer.future);
  }
}
