// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS()
library test.src.bootstrap.node;

import 'package:js/js.dart';
import 'package:package_resolver/package_resolver.dart';

import "../runner/browser/lazy_mapping.dart";
import "../runner/plugin/remote_platform_helpers.dart";
import "../runner/node/socket_channel.dart";
import '../util/stack_trace_mapper.dart';

@JS('\$dartTestGetSourceMap')
external Object _getSourceMap(String module);

/// Bootstraps a browser test to communicate with the test runner.
///
/// This should NOT be used directly, instead use the `test/pub_serve`
/// transformer which will bootstrap your test and call this method.
void internalBootstrapNodeTest(Function getMain()) {
  var channel = serializeSuite(getMain,
      stackTraceMapper: _getSourceMap == null
          ? null
          : new StackTraceMapper.parsed(new LazyMapping(),
              packageResolver: new SyncPackageResolver.root('packages/')));
  socketChannel().pipe(channel);
}
