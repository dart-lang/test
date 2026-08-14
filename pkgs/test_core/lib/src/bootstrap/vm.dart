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
  var platformChannel = MultiChannel<Object?>(
    IsolateChannel<Object?>.connectSend(sendPort),
  );
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
  Function Function() getMain,
  List<String> args,
) async {
  if (args.length != 1) {
    throw StateError('Expected a socket path, but got $args');
  }
  var socket = await Socket.connect(
    InternetAddress(args[0], type: InternetAddressType.unix),
    0,
  );
  var platformChannel = MultiChannel<Object?>(jsonSocketStreamChannel(socket));
  var testControlChannel = platformChannel.virtualChannel()
    ..pipe(serializeSuite(getMain));
  platformChannel.sink.add(testControlChannel.id);

  unawaited(
    platformChannel.stream.forEach((message) {
      assert(message == 'debug');
      debugger(message: 'Paused by test runner');
      platformChannel.sink.add('done');
    }),
  );
}

/// Bootstraps a global setup hook to execute, capture teardowns, and report
/// results back over an isolate port.
void internalBootstrapVmHook(
  Function Function() getMain,
  List<String> args,
  SendPort sendPort,
) async {
  final tearDowns = <FutureOr<void> Function()>[];
  final commandPort = ReceivePort();

  try {
    final mainFn = getMain();
    final result = await runZoned(() async {
      if (mainFn is FutureOr<Object?> Function(List<String>, SendPort)) {
        return await mainFn(args, sendPort);
      } else if (mainFn is FutureOr<Object?> Function(List<String>)) {
        return await mainFn(args);
      } else if (mainFn is FutureOr<Object?> Function()) {
        return await mainFn();
      } else {
        throw ArgumentError(
          'The global setup script must define a top-level `setUp` function '
          'with zero arguments, one List<String> argument, or (List<String>, SendPort).',
        );
      }
    }, zoneValues: {#test.global_teardowns: tearDowns});

    sendPort.send({
      'success': true,
      'result': result,
      'hasTearDown': tearDowns.isNotEmpty,
      'commandPort': tearDowns.isNotEmpty ? commandPort.sendPort : null,
    });

    if (tearDowns.isEmpty) {
      commandPort.close();
      return;
    }

    await for (var msg in commandPort) {
      if (msg is Map && msg['command'] == 'teardown') {
        final replyPort = msg['replyPort'] as SendPort;
        var errors = <(Object, StackTrace)>[];
        for (var tearDown in tearDowns.reversed) {
          try {
            await tearDown();
          } catch (error, stack) {
            errors.add((error, stack));
          }
        }

        try {
          if (errors.isEmpty) {
            replyPort.send({'success': true});
          } else {
            replyPort.send({
              'success': false,
              'error': errors.map((e) => e.$1.toString()).join('\n'),
              'stackTrace': errors.first.$2.toString(),
            });
          }
        } finally {
          commandPort.close();
        }
        break;
      }
    }
  } catch (error, stack) {
    commandPort.close();
    sendPort.send({
      'success': false,
      'error': error.toString(),
      'stackTrace': stack.toString(),
    });
  }
}
