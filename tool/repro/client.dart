// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: client.dart <socket_path> [id]');
    exit(1);
  }
  var socketPath = args[0];
  var id = args.length > 1 ? args[1] : '0';
  print('[CLIENT $id] Connecting to unix socket at $socketPath...');

  Socket socket;
  try {
    socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  } catch (e, s) {
    stderr.writeln('[CLIENT $id] Error connecting: $e\n$s');
    exit(1);
  }
  print('[CLIENT $id] Connected successfully!');

  // Send handshake message
  socket.writeln(jsonEncode({'id': id, 'event': 'started'}));
  await socket.flush();
  print('[CLIENT $id] Sent handshake data');

  // Stay alive until the server closes or destroys the socket connection
  print('[CLIENT $id] Waiting for server to close connection...');
  try {
    await socket.fold<void>(null, (_, __) {});
  } catch (e) {
    print('[CLIENT $id] Error reading socket: $e');
  }
  print('[CLIENT $id] Connection closed by server, exiting cleanly.');
}
