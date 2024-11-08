// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

import '../runner/plugin/remote_platform_helpers.dart';
import '../runner/plugin/shared_platform_helpers.dart';

/// Bootstraps a vm test to communicate with the test runner over an isolate.
void internalBootstrapVmTest(Function Function() getMain, SendPort sendPort) {
  var platformChannel =
      MultiChannel<Object?>(IsolateChannel<Object?>.connectSend(sendPort));
  var testControlChannel = platformChannel.virtualChannel()
    ..pipe(serializeSuite(getMain));
  platformChannel.sink.add(testControlChannel.id);

  platformChannel.stream.forEach((message) {
    assert(message == 'debug');
    debugger(message: 'Paused by test runner');
    platformChannel.sink.add('done');
  });
}

/// Bootstraps a native executable test to communicate with the test runner over
/// a socket.
void internalBootstrapNativeTest(
    Function Function() getMain, List<String> args) async {
  if (args.length != 2) {
    throw StateError(
        'Expected exactly two args, a host and a port, but got $args');
  }
  var socket = await Socket.connect(args[0], int.parse(args[1]));
  var platformChannel = MultiChannel<Object?>(jsonSocketStreamChannel(socket));
  var testControlChannel = platformChannel.virtualChannel()
    ..pipe(serializeSuite(getMain));
  platformChannel.sink.add(testControlChannel.id);

  unawaited(platformChannel.stream.forEach((message) {
    assert(message == 'debug');
    debugger(message: 'Paused by test runner');
    platformChannel.sink.add('done');
  }));
}
