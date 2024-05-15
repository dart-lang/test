// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS()
library;

import 'dart:async';
import 'dart:convert';

import 'package:js/js.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/src/runner/browser/dom.dart' as dom;

/// A class that exposes the test API to JS.
///
/// These are exposed so that tools like IDEs can interact with them via remote
/// debugging.
@JS()
@anonymous
@staticInterop
class _JSApi {
  external factory _JSApi(
      {void Function() resume, void Function() restartCurrent});
}

extension _JSApiExtension on _JSApi {
  /// Causes the test runner to resume running, as though the user had clicked
  /// the "play" button.
  // ignore: unused_element
  external Function get resume;

  /// Causes the test runner to restart the current test once it finishes
  /// running.
  // ignore: unused_element
  external Function get restartCurrent;
}

/// Sets the top-level `dartTest` object so that it's visible to JS.
@JS('dartTest')
external set _jsApi(_JSApi api);

/// The iframes created for each loaded test suite, indexed by the suite id.
final _iframes = <int, dom.HTMLIFrameElement>{};

/// Subscriptions created for each loaded test suite, indexed by the suite id.
final _subscriptions = <int, StreamSubscription<void>>{};
final _domSubscriptions = <int, dom.Subscription>{};

/// The URL for the current page.
final _currentUrl = Uri.parse(dom.window.location.href);

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
///                         (MessageChannel)
///                                │
///      ┏━ suite.html (in iframe) ┿━━━━━━━━━━━━━━━━━━━━━━━━━━┓
///      ┃                         │                          ┃
///      ┃         ┌──────────MultiChannel┬─────────┐         ┃
///      ┃         │          │     │     │         │         ┃
///      ┃   RemoteListener  test  test  test  running test   ┃
///      ┃                                                    ┃
///      ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
///
/// The host (this code) has a [MultiChannel] that splits the WebSocket
/// connection with the server. One connection is used for the host itself to
/// receive messages like "load a suite at this URL", and the rest are
/// connected to each test suite's iframe via a [MessageChannel].
///
/// Each iframe runs a `RemoteListener` which creates its own [MultiChannel] on
/// top of a [MessageChannel] connection. One connection is used for
/// the `RemoteListener`, which sends messages like "here are all the tests in
/// this suite". The rest are used for each test, receiving messages like
/// "start running". A new connection is also created whenever a test begins
/// running to send status messages about its progress.
///
/// It's of particular note that the suite's [MultiChannel] connection uses the
/// host's purely as a transport layer; neither is aware that the other is also
/// using [MultiChannel]. This is necessary, since the host doesn't share memory
/// with the suites and thus can't share its [MultiChannel] with them, but it
/// does mean that the server needs to be sure to nest its [MultiChannel]s at
/// the same place the client does.
void main() {
  dom.window.console.log('Dart test runner browser host running');
  if (_currentUrl.queryParameters['debug'] == 'true') {
    dom.document.body!.classList.add('debug');
  }

  runZonedGuarded(() {
    var serverChannel = _connectToServer();
    serverChannel.stream.listen((message) {
      switch (message) {
        case {
            'command': 'loadSuite',
            'channel': final num channel,
            'url': final String url,
            'id': final num id
          }:
          var suiteChannel = serverChannel.virtualChannel(channel.toInt());
          var iframeChannel = _connectToIframe(url, id.toInt());
          suiteChannel.pipe(iframeChannel);
        case {'command': 'displayPause'}:
          dom.document.body!.classList.add('paused');
        case {'command': 'resume'}:
          dom.document.body!.classList.remove('paused');
        case {'command': 'closeSuite', 'id': final id}:
          _iframes.remove(id)!.remove();
          _subscriptions.remove(id)?.cancel();
          _domSubscriptions.remove(id)?.cancel();
        default:
          dom.window.console
              .warn('Unhandled message from test runner: $message');
      }
    });

    // Send periodic pings to the test runner so it can know when the browser is
    // paused for debugging.
    Timer.periodic(const Duration(seconds: 1),
        (_) => serverChannel.sink.add({'command': 'ping'}));

    var play = dom.document.querySelector('#play');
    play!.addEventListener('click', allowInterop((_) {
      if (!dom.document.body!.classList.contains('paused')) return;
      dom.document.body!.classList.remove('paused');
      serverChannel.sink.add({'command': 'resume'});
    }));

    _jsApi = _JSApi(resume: allowInterop(() {
      if (!dom.document.body!.classList.contains('paused')) return;
      dom.document.body!.classList.remove('paused');
      serverChannel.sink.add({'command': 'resume'});
    }), restartCurrent: allowInterop(() {
      serverChannel.sink.add({'command': 'restart'});
    }));
  }, (error, stackTrace) {
    dom.window.console.warn('$error\n${Trace.from(stackTrace).terse}');
  });
}

/// Creates a [MultiChannel] connection to the server, using a [WebSocket] as
/// the underlying protocol.
MultiChannel<dynamic> _connectToServer() {
  // The `managerUrl` query parameter contains the WebSocket URL of the remote
  // [BrowserManager] with which this communicates.
  var webSocket =
      dom.createWebSocket(_currentUrl.queryParameters['managerUrl']!);

  var controller = StreamChannelController<Object?>(sync: true);
  webSocket.addEventListener('message', allowInterop((message) {
    controller.local.sink
        .add(jsonDecode((message as dom.MessageEvent).data as String));
  }));

  controller.local.stream
      .listen((message) => webSocket.send(jsonEncode(message)));

  return MultiChannel(controller.foreign);
}

/// Creates an iframe with `src` [url] and expects a message back to connect a
/// message channel with the suite running in the frame.
///
/// [id] identifies the suite loaded in this iframe.
///
/// Before the frame is attached, adds a listener for `window.onMessage` which
/// filters to only the messages coming from this frame (by it's URL) and
/// expects the first message to be either an initialization message, (coming
/// from the browser bootstrap message channel initialization), or a map with
/// the key 'exception' set to true and details in the value for 'data' (coming
/// from `dart.js` due to a load exception).
///
/// Legacy bootstrap implementations send a `{'ready': true}` message as a
/// signal for this host to create a [MessageChannel] and send the port through
/// the frame's `window.onMessage` channel.
///
/// Upcoming bootstrap implementations will send the string 'port' and include a
/// port for a prepared [MessageChannel].
///
/// Returns a [StreamChannel] which will be connected to the frame once the
/// message channel port is active.
StreamChannel<dynamic> _connectToIframe(String url, int id) {
  var suiteUrl = Uri.parse(url).removeFragment();
  dom.window.console.log('Starting suite $suiteUrl');
  var iframe = dom.createHTMLIFrameElement();
  _iframes[id] = iframe;
  var controller = StreamChannelController<Object?>(sync: true);

  late dom.Subscription windowSubscription;
  windowSubscription =
      dom.Subscription(dom.window, 'message', allowInterop((dom.Event event) {
    // A message on the Window can theoretically come from any website. It's
    // very unlikely that a malicious site would care about hacking someone's
    // unit tests, let alone be able to find the test server while it's
    // running, but it's good practice to check the origin anyway.
    var message = event as dom.MessageEvent;
    if (message.origin != dom.window.location.origin) return;
    // Disambiguate between frames for different test suites.
    // Depending on the source type, the `location.href` may be missing.
    if (message.source.location?.href != iframe.src) return;

    message.stopPropagation();
    windowSubscription.cancel();

    switch (message.data) {
      case 'port':
        dom.window.console.log('Connecting channel for suite $suiteUrl');
        // The frame is starting and sending a port to forward for the suite.
        final port = message.ports.first;
        assert(!_domSubscriptions.containsKey(id));
        _domSubscriptions[id] =
            dom.Subscription(port, 'message', allowInterop((event) {
          controller.local.sink.add((event as dom.MessageEvent).data);
        }));
        port.start();

        assert(!_subscriptions.containsKey(id));
        _subscriptions[id] = controller.local.stream.listen(port.postMessage);
      case {'exception': true, 'data': final data}:
        // This message from `dart.js` indicates that an exception occurred
        // loading the test.
        controller.local.sink.add(data);
    }
  }));

  iframe.src = url;
  dom.document.body!.appendChild(iframe);
  dom.window.console.log('Appended iframe with src $url');

  return controller.foreign;
}
