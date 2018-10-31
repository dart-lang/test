// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../runner/node/socket_channel.dart';

import 'package:test_core/src/runner/plugin/remote_platform_helpers.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports

/// Bootstraps a browser test to communicate with the test runner.
void internalBootstrapNodeTest(Function getMain()) {
  var channel = serializeSuite(getMain, beforeLoad: () async {
    var serialized = await suiteChannel("test.node.mapper").stream.first;
    if (serialized == null || serialized is! Map) return;
    setStackTraceMapper(JSStackTraceMapper.deserialize(serialized as Map));
  });
  socketChannel().pipe(channel);
}
