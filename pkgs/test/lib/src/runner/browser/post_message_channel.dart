// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_util';

import 'package:stream_channel/stream_channel.dart';

import 'dom.dart' as dom;

/// Constructs a [StreamChannel] wrapping a new [MessageChannel] communicating
/// with the host page.
///
/// Sends a [MessagePort] to the host page for the channel.
StreamChannel<Object?> postMessageChannel() {
  dom.window.console.log('Suite starting, sending channel to host');
  var controller = StreamChannelController<Object?>(sync: true);
  var channel = dom.createMessageChannel();
  dom.window.parent
      .postMessage('port', dom.window.location.origin, [channel.port2]);
  var portSubscription = dom.Subscription(channel.port1, 'message',
      allowInterop((dom.Event event) {
    controller.local.sink.add((event as dom.MessageEvent).data);
  }));
  channel.port1.start();

  controller.local.stream
      .listen(channel.port1.postMessage, onDone: portSubscription.cancel);

  return controller.foreign;
}
