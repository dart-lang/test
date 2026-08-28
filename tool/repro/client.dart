// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: client.dart <socket_path> [mode]');
    exit(1);
  }
  var socketPath = args[0];
  var mode = args.length > 1 ? args[1] : 'stay_alive';
  print('[CLIENT] Connecting to unix socket at $socketPath (mode: $mode)...');

  Socket socket;
  try {
    socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  } catch (e, s) {
    stderr.writeln('[CLIENT] Error connecting: $e\n$s');
    exit(1);
  }
  print('[CLIENT] Connected successfully!');

  if (mode == 'send_data') {
    socket.writeln('hello from client');
    await socket.flush();
    print('[CLIENT] Sent data');
  }

  if (mode == 'stay_alive' || mode == 'send_data') {
    print('[CLIENT] Staying alive until server closes connection...');
    try {
      await socket.fold<void>(null, (_, __) {});
    } catch (_) {}
    print('[CLIENT] Connection closed, exiting.');
  } else {
    await socket.close();
    print('[CLIENT] Closed socket, exiting.');
  }
}
