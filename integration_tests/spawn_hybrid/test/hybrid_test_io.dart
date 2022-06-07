// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('kills the isolate when the test closes the channel', () async {
    var channel = spawnHybridCode('''
        import "dart:async";
        import "dart:io";

        import "package:shelf/shelf.dart" as shelf;
        import "package:shelf/shelf_io.dart" as io;
        import "package:stream_channel/stream_channel.dart";

        hybridMain(StreamChannel channel) async {
          var server = await ServerSocket.bind("localhost", 0);
          server.listen(null);
          channel.sink.add(server.port);
        }
      ''');

    // Expect that the socket disconnects at some point (presumably when the
    // isolate closes).
    var port = await channel.stream.first as int;
    var socket = await Socket.connect('localhost', port);
    expect(socket.listen(null).asFuture(), completes);

    await channel.sink.close();
  });

  test('spawnHybridUri(): supports absolute file: URIs', () async {
    expect(
        spawnHybridUri(p.toUri(p.absolute(
                p.relative(p.join('test', 'util', 'emits_numbers.dart')))))
            .stream
            .toList(),
        completion(equals([1, 2, 3])));
  });
}
