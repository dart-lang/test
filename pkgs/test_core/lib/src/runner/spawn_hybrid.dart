// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

import '../util/dart.dart' as dart;

import 'package:test_api/src/util/remote_exception.dart'; // ignore: implementation_imports

/// Spawns a hybrid isolate from [url] with the given [message], and returns a
/// [StreamChannel] that communicates with it.
///
/// This connects the main isolate to the hybrid isolate, whereas
/// `lib/src/frontend/spawn_hybrid.dart` connects the test isolate to the main
/// isolate.
StreamChannel spawnHybridUri(String url, Object? message) {
  return StreamChannelCompleter.fromFuture(() async {
    var port = ReceivePort();
    var onExitPort = ReceivePort();
    try {
      var code = '''
        import "package:test_core/src/runner/hybrid_listener.dart";

        import "${url.replaceAll(r'$', '%24')}" as lib;

        void main(_, List data) => listen(() => lib.hybridMain, data);
      ''';

      var isolate = await dart.runInIsolate(code, [port.sendPort, message],
          onExit: onExitPort.sendPort);

      // Ensure that we close [port] and [channel] when the isolate exits.
      var disconnector = Disconnector();
      onExitPort.listen((_) {
        disconnector.disconnect();
        onExitPort.close();
      });

      return IsolateChannel.connectReceive(port)
          .transform(disconnector)
          .transformSink(StreamSinkTransformer.fromHandlers(handleDone: (sink) {
        // If the user closes the stream channel, kill the isolate.
        isolate.kill();
        onExitPort.close();
        sink.close();
      }));
    } catch (error, stackTrace) {
      port.close();
      onExitPort.close();

      // Make sure any errors in spawning the isolate are forwarded to the test.
      return StreamChannel(
          Stream.fromFuture(Future.value({
            'type': 'error',
            'error': RemoteException.serialize(error, stackTrace)
          })),
          NullStreamSink());
    }
  }());
}
