// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';

import '../backend/invoker.dart';
import '../util/remote_exception.dart';
import '../utils.dart';

/// A transformer that handles messages from the spawned isolate and ensures
/// that messages sent to it are JSON-encodable.
final _transformer = new StreamChannelTransformer(
    new StreamTransformer.fromHandlers(handleData: (message, sink) {
      switch (message['type']) {
        case 'data':
          sink.add(message['data']);
          break;

        case 'print':
          print(message['line']);
          break;

        case 'error':
          var error = RemoteException.deserialize(message['error']);
          sink.addError(error.error, error.stackTrace);
          break;
      }
    }), new StreamSinkTransformer.fromHandlers(handleData: (message, sink) {
      ensureJsonEncodable(message);
      sink.add(message);
    }));

/// Spawns a VM isolate for the given [uri], which may be a [Uri] or a [String].
///
/// This allows browser tests to spawn servers with which they can communicate
/// to test client/server interactions. It can also be used by VM tests to
/// easily spawn an isolate.
///
/// The Dart file at [uri] must define a top-level `hybridMain()` function that
/// takes a `StreamChannel` argument and, optionally, an `Object` argument to
/// which [message] will be passed. Note that [message] must be JSON-encodable.
/// For example:
///
/// ```dart
/// import "package:stream_channel/stream_channel.dart";
///
/// hybridMain(StreamChannel channel, Object message) {
///   // ...
/// }
/// ```
///
/// If [uri] is relative, it will be interpreted relative to the `file:` URL for
/// the test suite being executed. If it's a `package:` URL, it will be resolved
/// using the current package's dependency constellation.
///
/// Returns a [StreamChannel] that's connected to the channel passed to
/// `hybridMain()`. Only JSON-encodable objects may be sent through this
/// channel. If the channel is closed, the hybrid isolate is killed. If the
/// isolate is killed, the channel's stream will emit a "done" event.
///
/// Any unhandled errors loading or running the hybrid isolate will be emitted
/// as errors over the channel's stream. Any calls to `print()` in the hybrid
/// isolate will be printed as though they came from the test that created the
/// isolate.
///
/// Code in the hybrid isolate is not considered to be running in a test
/// context, so it can't access test functions like `expect()` and
/// `expectAsync()`.
///
/// **Note**: If you use this API, be sure to add a dependency on the
/// **`stream_channel` package, since you're using its API as well!
StreamChannel spawnHybridUri(uri, {Object message}) {
  Uri parsedUrl;
  if (uri is Uri) {
    parsedUrl = uri;
  } else if (uri is String) {
    parsedUrl = Uri.parse(uri);
  } else {
    throw new ArgumentError.value(uri, "uri", "must be a Uri or a String.");
  }

  String uriString;
  if (parsedUrl.scheme.isEmpty) {
    var suitePath = Invoker.current.liveTest.suite.path;
    uriString = p.url.join(
        p.url.dirname(p.toUri(p.absolute(suitePath)).toString()),
        parsedUrl.toString());
  } else {
    uriString = uri.toString();
  }

  return _spawn(uriString, message);
}

/// Spawns a VM isolate that runs the given [dartCode], which is loaded as the
/// contents of a Dart library.
///
/// This allows browser tests to spawn servers with which they can communicate
/// to test client/server interactions. It can also be used by VM tests to
/// easily spawn an isolate.
///
/// The [dartCode] must define a top-level `hybridMain()` function that takes a
/// `StreamChannel` argument and, optionally, an `Object` argument to which
/// [message] will be passed. Note that [message] must be JSON-encodable. For
/// example:
///
/// ```dart
/// import "package:stream_channel/stream_channel.dart";
///
/// hybridMain(StreamChannel channel, Object message) {
///   // ...
/// }
/// ```
///
/// Returns a [StreamChannel] that's connected to the channel passed to
/// `hybridMain()`. Only JSON-encodable objects may be sent through this
/// channel. If the channel is closed, the hybrid isolate is killed. If the
/// isolate is killed, the channel's stream will emit a "done" event.
///
/// Any unhandled errors loading or running the hybrid isolate will be emitted
/// as errors over the channel's stream. Any calls to `print()` in the hybrid
/// isolate will be printed as though they came from the test that created the
/// isolate.
///
/// Code in the hybrid isolate is not considered to be running in a test
/// context, so it can't access test functions like `expect()` and
/// `expectAsync()`.
///
/// **Note**: If you use this API, be sure to add a dependency on the
/// **`stream_channel` package, since you're using its API as well!
StreamChannel spawnHybridCode(String dartCode, {Object message}) {
  var uri = new Uri.dataFromString(dartCode,
      encoding: UTF8, mimeType: 'application/dart');
  return _spawn(uri.toString(), message);
}

/// Like [spawnHybridUri], but doesn't take [Uri] objects and doesn't handle
/// relative URLs.
StreamChannel _spawn(String uri, Object message) {
  var channel = Zone.current[#test.runner.test_channel] as MultiChannel;
  if (channel == null) {
    // TODO(nweiz): Link to an issue tracking support when running the test file
    // directly.
    throw new UnsupportedError(
        "Can't connect to the test runner.\n"
        'spawnHybridUri() is currently only supported within "pub run test".');
  }

  ensureJsonEncodable(message);

  var isolateChannel = channel.virtualChannel();
  channel.sink.add({
    "type": "spawn-hybrid-uri",
    "url": uri,
    "message": message,
    "channel": isolateChannel.id
  });

  return isolateChannel.transform(_transformer);
}
