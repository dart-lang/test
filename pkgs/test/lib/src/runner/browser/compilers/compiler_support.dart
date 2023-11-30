// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test_api/backend.dart' show StackTraceMapper, SuitePlatform;
import 'package:test_core/src/runner/suite.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // ignore: implementation_imports

/// The shared interface for all compiler support libraries.
abstract class CompilerSupport {
  /// The URL at which this compiler serves its tests.
  ///
  /// Each compiler serves its tests under a different directory.
  Uri get serverUrl;

  /// Compiles [dartPath] using [suiteConfig] for [platform].
  Future<void> compileSuite(
      String dartPath, SuiteConfiguration suiteConfig, SuitePlatform platform);

  /// Retrieves a stack trace mapper for [dartPath] if available.
  StackTraceMapper? stackTraceMapperForPath(String dartPath);

  /// Returns the eventual URI for the web socket, as well as the channel itself
  /// once the connection is established.
  (Uri uri, Future<WebSocketChannel> socket) get webSocket;

  /// Closes down anything necessary for this implementation.
  Future<void> close();
}
