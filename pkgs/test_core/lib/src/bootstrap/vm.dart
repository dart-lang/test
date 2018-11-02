// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:isolate";

import "package:stream_channel/stream_channel.dart";

import "package:test_core/src/runner/plugin/remote_platform_helpers.dart";
import "package:test_core/src/runner/vm/catch_isolate_errors.dart";

/// Bootstraps a vm test to communicate with the test runner.
void internalBootstrapVmTest(Function getMain(), SendPort sendPort) {
  var channel = serializeSuite(() {
    catchIsolateErrors();
    return getMain();
  });
  IsolateChannel.connectSend(sendPort).pipe(channel);
}
