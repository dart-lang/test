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

/// Constructs a [StreamChannel] wrapping `postMessage` communication with the
/// host page.
StreamChannel postMessageChannel() {
  var controller = new StreamChannelController(sync: true);

  window.onMessage.listen((message) {
    // A message on the Window can theoretically come from any website. It's
    // very unlikely that a malicious site would care about hacking someone's
    // unit tests, let alone be able to find the test server while it's
    // running, but it's good practice to check the origin anyway.
    if (message.origin != window.location.origin) return;
    message.stopPropagation();

    controller.local.sink.add(message.data);
  });

  controller.local.stream.listen((data) {
    // TODO(nweiz): Stop manually adding href here once issue 22554 is
    // fixed.
    _postParentMessage(jsify({"href": window.location.href, "data": data}),
        window.location.origin);
  });

  // Send a ready message once we're listening so the host knows it's safe to
  // start sending events.
  _postParentMessage(jsify({"href": window.location.href, "ready": true}),
      window.location.origin);

  return controller.foreign;
}
