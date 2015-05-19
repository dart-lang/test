// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.browser_manager;

import 'dart:async';
import 'dart:convert';

import 'package:http_parser/http_parser.dart';
import 'package:pool/pool.dart';

import '../../backend/metadata.dart';
import '../../backend/suite.dart';
import '../../backend/test_platform.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../util/stack_trace_mapper.dart';
import '../../utils.dart';
import '../load_exception.dart';
import 'iframe_test.dart';

/// A class that manages the connection to a single running browser.
///
/// This is in charge of telling the browser which test suites to load and
/// converting its responses into [Suite] objects.
class BrowserManager {
  /// The browser that this is managing.
  final TestPlatform browser;

  /// The channel used to communicate with the browser.
  ///
  /// This is connected to a page running `static/host.dart`.
  final MultiChannel _channel;

  /// A pool that ensures that limits the number of initial connections the
  /// manager will wait for at once.
  ///
  /// This isn't the *total* number of connections; any number of iframes may be
  /// loaded in the same browser. However, the browser can only load so many at
  /// once, and we want a timeout in case they fail so we only wait for so many
  /// at once.
  final _pool = new Pool(8);

  /// Creates a new BrowserManager that communicates with [browser] over
  /// [webSocket].
  BrowserManager(this.browser, CompatibleWebSocket webSocket)
      : _channel = new MultiChannel(
          webSocket.map(JSON.decode),
          mapSink(webSocket, JSON.encode));

  /// Tells the browser the load a test suite from the URL [url].
  ///
  /// [url] should be an HTML page with a reference to the JS-compiled test
  /// suite. [path] is the path of the original test suite file, which is used
  /// for reporting. [metadata] is the parsed metadata for the test suite.
  ///
  /// If [mapper] is passed, it's used to map stack traces for errors coming
  /// from this test suite.
  Future<Suite> loadSuite(String path, Uri url, Metadata metadata,
      {StackTraceMapper mapper}) {
    url = url.replace(fragment: Uri.encodeFull(JSON.encode({
      "metadata": metadata.serialize(),
      "browser": browser.identifier
    })));

    // The stream may close before emitting a value if the browser is killed
    // prematurely (e.g. via Control-C).
    var suiteChannel = _channel.virtualChannel();
    return _pool.withResource(() {
      _channel.sink.add({
        "command": "loadSuite",
        "url": url.toString(),
        "channel": suiteChannel.id
      });

      // Create a nested MultiChannel because the iframe will be using a channel
      // wrapped within the host's channel.
      suiteChannel = new MultiChannel(suiteChannel.stream, suiteChannel.sink);

      return maybeFirst(suiteChannel.stream)
          .timeout(new Duration(seconds: 15), onTimeout: () {
        throw new LoadException(
            path,
            "Timed out waiting for the test suite to connect on "
                "${browser.name}.");
      });
    }).then((response) {
      if (response == null) return null;

      if (response["type"] == "loadException") {
        return new Future.error(new LoadException(path, response["message"]));
      } else if (response["type"] == "error") {
        var asyncError = RemoteException.deserialize(response["error"]);
        return new Future.error(
            new LoadException(path, asyncError.error),
            asyncError.stackTrace);
      }

      return new Suite(response["tests"].map((test) {
        var testMetadata = new Metadata.deserialize(test['metadata']);
        var testChannel = suiteChannel.virtualChannel(test['channel']);
        return new IframeTest(test['name'], testMetadata, testChannel,
            mapper: mapper);
      }), metadata: metadata, path: path);
    });
  }
}
