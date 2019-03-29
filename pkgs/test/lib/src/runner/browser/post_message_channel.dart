// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS()
library test.src.runner.browser.post_message_channel;

import 'dart:html';
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:stream_channel/stream_channel.dart';

// Avoid using this from dart:html to work around dart-lang/sdk#32113.
@JS("window.parent.postMessage")
external void _postParentMessage(Object message, String targetOrigin);

/// Constructs a [StreamChannel] wrapping [MessageChannel] communication with
/// the host page.
StreamChannel postMessageChannel() {
  var controller = StreamChannelController(sync: true);

  // Listen for a message from the host that transfers a message port. Using
  // `firstWhere` automatically unsubscribes from further messages. This is
  // important to prevent multiple subscriptions if the test is ever hot
  // restarted.
  window.onMessage.firstWhere((message) {
    // A message on the Window can theoretically come from any website. It's
    // very unlikely that a malicious site would care about hacking someone's
    // unit tests, let alone be able to find the test server while it's
    // running, but it's good practice to check the origin anyway.
    return message.origin == window.location.origin && message.data == "port";
  }).then((message) {
    var port = message.ports.first;

    port.onMessage.listen((message) {
      controller.local.sink.add(message.data);
    });

    // TODO(nweiz): Stop manually adding href here once issue 22554 is
    // fixed.
    controller.local.stream.listen((data) {
      port.postMessage({"href": window.location.href, "data": data});
    }, onDone: () {
      port.postMessage({"href": window.location.href, "event": "done"});
    });
  });

  // Send a ready message once we're listening so the host knows it's safe to
  // start sending events.
  _postParentMessage(jsify({"href": window.location.href, "ready": true}),
      window.location.origin);

  return controller.foreign;
}
