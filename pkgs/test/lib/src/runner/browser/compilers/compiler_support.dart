// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:test_api/backend.dart' show StackTraceMapper, SuitePlatform;
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports
import 'package:web_socket_channel/web_socket_channel.dart'; // ignore: implementation_imports

/// The shared interface for all compiler support libraries.
abstract class CompilerSupport {
  /// The global test runner configuration.
  final Configuration config;

  /// The default template path.
  final String defaultTemplatePath;

  CompilerSupport(this.config, this.defaultTemplatePath);

  /// The URL at which this compiler serves its tests.
  ///
  /// Each compiler serves its tests under a different directory.
  Uri get serverUrl;

  /// Compiles [dartPath] using [suiteConfig] for [platform].
  ///
  /// [dartPath] is the path to the original `.dart` test suite, relative to the
  /// package root.
  Future<void> compileSuite(
      String dartPath, SuiteConfiguration suiteConfig, SuitePlatform platform);

  /// Retrieves a stack trace mapper for [dartPath] if available.
  ///
  /// [dartPath] is the path to the original `.dart` test suite, relative to the
  /// package root.
  StackTraceMapper? stackTraceMapperForPath(String dartPath);

  /// Returns the eventual URI for the web socket, as well as the channel itself
  /// once the connection is established.
  (Uri uri, Future<WebSocketChannel> socket) get webSocket;

  /// Closes down anything necessary for this implementation.
  Future<void> close();

  /// A handler that serves html wrapper files used to bootstrap tests.
  shelf.Response htmlWrapperHandler(shelf.Request request);
}

mixin JsHtmlWrapper on CompilerSupport {
  @override
  shelf.Response htmlWrapperHandler(shelf.Request request) {
    var path = p.fromUri(request.url);

    if (path.endsWith('.html')) {
      var test = p.setExtension(path, '.dart');
      var scriptBase = htmlEscape.convert(p.basename(test));
      var link = '<link rel="x-dart-test" href="$scriptBase">';
      var testName = htmlEscape.convert(test);
      var template = config.customHtmlTemplatePath ?? defaultTemplatePath;
      var contents = File(template).readAsStringSync();
      var processedContents = contents
          // Checked during loading phase that there is only one {{testScript}} placeholder.
          .replaceFirst('{{testScript}}', link)
          .replaceAll('{{testName}}', testName);
      return shelf.Response.ok(processedContents,
          headers: {'Content-Type': 'text/html'});
    }

    return shelf.Response.notFound('Not found.');
  }
}

mixin WasmHtmlWrapper on CompilerSupport {
  @override
  shelf.Response htmlWrapperHandler(shelf.Request request) {
    var path = p.fromUri(request.url);

    if (path.endsWith('.html')) {
      var test = '${p.withoutExtension(path)}.dart';
      var scriptBase = htmlEscape.convert(p.basename(test));
      var link = '<link rel="x-dart-test" href="$scriptBase">';
      var testName = htmlEscape.convert(test);
      var template = config.customHtmlTemplatePath ?? defaultTemplatePath;
      var contents = File(template).readAsStringSync();
      var jsRuntime = p.basename('$test.browser_test.dart.mjs');
      var wasmData = '<data id="WasmBootstrapInfo" '
          'data-wasmurl="${p.basename('$test.browser_test.dart.wasm')}" '
          'data-jsruntimeurl="$jsRuntime"></data>';
      var processedContents = contents
          // Checked during loading phase that there is only one {{testScript}} placeholder.
          .replaceFirst('{{testScript}}', '$link\n$wasmData')
          .replaceAll('{{testName}}', testName);
      return shelf.Response.ok(processedContents,
          headers: {'Content-Type': 'text/html'});
    }

    return shelf.Response.notFound('Not found.');
  }
}
