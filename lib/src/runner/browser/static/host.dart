// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.host;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js' as js;

import 'package:stack_trace/stack_trace.dart';
import 'package:test/src/util/multi_channel.dart';
import 'package:test/src/util/stream_channel.dart';

/// The iframes created for each loaded test suite, indexed by the suite id.
final _iframes = new Map<int, IFrameElement>();

// TODO(nweiz): test this once we can run browser tests.
/// Code that runs in the browser and loads test suites at the server's behest.
///
/// One instance of this runs for each browser. When the server tells it to load
/// a test, it starts an iframe pointing at that test's code; from then on, it
/// just relays messages between the two.
///
/// The browser uses two layers of [MultiChannel]s when communicating with the
/// server:
///
///                                       server
///                                         │
///                                    (WebSocket)
///                                         │
///                    ┏━ host.html ━━━━━━━━┿━━━━━━━━━━━━━━━━━┓
///                    ┃                    │                 ┃
///                    ┃    ┌──────┬───MultiChannel─────┐     ┃
///                    ┃    │      │      │      │      │     ┃
///                    ┃   host  suite  suite  suite  suite   ┃
///                    ┃           │      │      │      │     ┃
///                    ┗━━━━━━━━━━━┿━━━━━━┿━━━━━━┿━━━━━━┿━━━━━┛
///                                │      │      │      │
///                                │     ...    ...    ...
///                                │
///                          (postMessage)
///                                │
///      ┏━ suite.html (in iframe) ┿━━━━━━━━━━━━━━━━━━━━━━━━━━┓
///      ┃                         │                          ┃
///      ┃         ┌──────────MultiChannel┬─────────┐         ┃
///      ┃         │          │     │     │         │         ┃
///      ┃   IframeListener  test  test  test  running test   ┃
///      ┃                                                    ┃
///      ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
///
/// The host (this code) has a [MultiChannel] that splits the WebSocket
/// connection with the server. One connection is used for the host itself to
/// receive messages like "load a suite at this URL", and the rest are connected
/// to each test suite's iframe via `postMessage`.
///
/// Each iframe then has its own [MultiChannel] which takes its `postMessage`
/// connection and splits it again. One connection is used for the
/// [IframeListener], which sends messages like "here are all the tests in this
/// suite". The rest are used for each test, receiving messages like "start
/// running". A new connection is also created whenever a test begins running to
/// send status messages about its progress.
///
/// It's of particular note that the suite's [MultiChannel] connection uses the
/// host's purely as a transport layer; neither is aware that the other is also
/// using [MultiChannel]. This is necessary, since the host doesn't share memory
/// with the suites and thus can't share its [MultiChannel] with them, but it
/// does mean that the server needs to be sure to nest its [MultiChannel]s at
/// the same place the client does.
void main() {
  // This tells content_shell not to close immediately after the page has
  // rendered.
  var testRunner = js.context['testRunner'];
  if (testRunner != null) testRunner.callMethod('waitUntilDone', []);

  runZoned(() {
    var serverChannel = _connectToServer();
    serverChannel.stream.listen((message) {
      if (message['command'] == 'loadSuite') {
        var suiteChannel = serverChannel.virtualChannel(message['channel']);
        var iframeChannel = _connectToIframe(message['url'], message['id']);
        suiteChannel.pipe(iframeChannel);
      } else {
        assert(message['command'] == 'closeSuite');
        _iframes[message['id']].remove();
      }
    });
  }, onError: (error, stackTrace) {
    print("$error\n${new Trace.from(stackTrace).terse}");
  });
}

/// Creates a [MultiChannel] connection to the server, using a [WebSocket] as
/// the underlying protocol.
MultiChannel _connectToServer() {
  // The `managerUrl` query parameter contains the WebSocket URL of the remote
  // [BrowserManager] with which this communicates.
  var currentUrl = Uri.parse(window.location.href);
  var webSocket = new WebSocket(currentUrl.queryParameters['managerUrl']);

  var inputController = new StreamController(sync: true);
  webSocket.onMessage.listen(
      (message) => inputController.add(JSON.decode(message.data)));

  var outputController = new StreamController(sync: true);
  outputController.stream.listen(
      (message) => webSocket.send(JSON.encode(message)));

  return new MultiChannel(inputController.stream, outputController.sink);
}

/// Creates an iframe with `src` [url] and establishes a connection to it using
/// `postMessage`.
///
/// [id] identifies the suite loaded in this iframe.
StreamChannel _connectToIframe(String url, int id) {
  var iframe = new IFrameElement();
  _iframes[id] = iframe;
  iframe.src = url;
  document.body.children.add(iframe);

  var inputController = new StreamController(sync: true);
  var outputController = new StreamController(sync: true);

  // Use this to avoid sending a message to the iframe before it's sent a
  // message to us. This ensures that no messages get dropped on the floor.
  var readyCompleter = new Completer();

  // TODO(nweiz): use MessageChannel once Firefox supports it
  // (http://caniuse.com/#search=MessageChannel).
  window.onMessage.listen((message) {
    // A message on the Window can theoretically come from any website. It's
    // very unlikely that a malicious site would care about hacking someone's
    // unit tests, let alone be able to find the test server while it's
    // running, but it's good practice to check the origin anyway.
    if (message.origin != window.location.origin) return;

    // TODO(nweiz): Stop manually checking href here once issue 22554 is
    // fixed.
    if (message.data["href"] != iframe.src) return;

    message.stopPropagation();
    inputController.add(message.data["data"]);
    if (!readyCompleter.isCompleted) readyCompleter.complete();
  });

  outputController.stream.listen((message) async {
    await readyCompleter.future;
    iframe.contentWindow.postMessage(message, window.location.origin);
  });

  return new StreamChannel(inputController.stream, outputController.sink);
}
