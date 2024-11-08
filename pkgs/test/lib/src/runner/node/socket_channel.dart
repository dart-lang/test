// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:stream_channel/stream_channel.dart';

@JS('process.argv')
external JSArray<JSString> get _args;

extension type _Net._(JSObject _) {
  external _Socket connect(int port);
}

extension type _Socket._(JSObject _) {
  external void setEncoding(JSString encoding);
  external void on(JSString event, JSFunction callback);
  external void write(JSString data);
}

/// Returns a [StreamChannel] of JSON-encodable objects that communicates over a
/// socket whose port is given by `process.argv[2]`.
Future<StreamChannel<Object?>> socketChannel() async {
  final net = (await importModule('node:net'.toJS).toDart) as _Net;

  var socket = net.connect(int.parse(_args.toDart[2].toDart));
  socket.setEncoding('utf8'.toJS);

  var socketSink = StreamController<Object?>(sync: true)
    ..stream.listen((event) => socket.write('${jsonEncode(event)}\n'.toJS));

  var socketStream = StreamController<String>(sync: true);
  socket.on(
    'data'.toJS,
    ((JSString chunk) => socketStream.add(chunk.toDart)).toJS,
  );

  return StreamChannel.withCloseGuarantee(
      socketStream.stream.transform(const LineSplitter()).map(jsonDecode),
      socketSink);
}
