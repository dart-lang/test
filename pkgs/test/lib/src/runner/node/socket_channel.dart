// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:stream_channel/stream_channel.dart';

@JS('process.argv')
external JSArray<JSString> get _args;

extension type _Fs._(JSObject _) {
  external JSString readFileSync(JSString path, JSString encoding);
}

extension type _Net._(JSObject _) {
  external _Socket connect(int port);
}

extension type _Socket._(JSObject _) {
  external void setEncoding(JSString encoding);
  external void on(JSString event, JSFunction callback);
  external void write(JSString data);
}

/// Returns a [StreamChannel] of JSON-encodable objects that communicates over a
/// socket whose authentication config file is given by `process.argv[2]`.
Future<StreamChannel<Object?>> socketChannel() async {
  final fs = (await importModule('node:fs'.toJS).toDart) as _Fs;
  final net = (await importModule('node:net'.toJS).toDart) as _Net;

  var authJson = fs.readFileSync(_args.toDart[2], 'utf8'.toJS).toDart;
  var auth = jsonDecode(authJson) as Map<String, dynamic>;
  var port = auth['port'] as int;
  var secret = auth['secret'] as String;

  var socket = net.connect(port);
  socket.setEncoding('utf8'.toJS);

  var socketSink = StreamController<Object?>(sync: true)
    ..stream.listen((event) => socket.write('${jsonEncode(event)}\n'.toJS));

  var socketStream = StreamController<String>(sync: true);
  socket.on(
    'data'.toJS,
    ((JSString chunk) => socketStream.add(chunk.toDart)).toJS,
  );

  var channel = StreamChannel.withCloseGuarantee(
    socketStream.stream.transform(const LineSplitter()).map(jsonDecode),
    socketSink,
  );

  channel.sink.add(secret);
  return channel;
}
