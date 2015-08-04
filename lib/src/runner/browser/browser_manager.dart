// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.browser_manager;

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pool/pool.dart';

import '../../backend/metadata.dart';
import '../../backend/test_platform.dart';
import '../../util/cancelable_future.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../util/stack_trace_mapper.dart';
import '../../utils.dart';
import '../application_exception.dart';
import '../environment.dart';
import '../load_exception.dart';
import '../runner_suite.dart';
import 'browser.dart';
import 'chrome.dart';
import 'content_shell.dart';
import 'dartium.dart';
import 'firefox.dart';
import 'iframe_test.dart';
import 'internet_explorer.dart';
import 'phantom_js.dart';
import 'safari.dart';

/// A class that manages the connection to a single running browser.
///
/// This is in charge of telling the browser which test suites to load and
/// converting its responses into [Suite] objects.
class BrowserManager {
  /// The browser instance that this is connected to via [_channel].
  final Browser _browser;

  // TODO(nweiz): Consider removing the duplication between this and
  // [_browser.name].
  /// The [TestPlatform] for [_browser].
  final TestPlatform _platform;

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

  /// The ID of the next suite to be loaded.
  ///
  /// This is used to ensure that the suites can be referred to consistently
  /// across the client and server.
  int _suiteId = 0;

  /// Whether the channel to the browser has closed.
  bool _closed = false;

  /// The completer for [_BrowserEnvironment.displayPause].
  ///
  /// This will be `null` as long as the browser isn't displaying a pause
  /// screen.
  CancelableCompleter _pauseCompleter;

  /// The environment to attach to each suite.
  Future<_BrowserEnvironment> _environment;

  /// Starts the browser identified by [platform] and has it connect to [url].
  ///
  /// [url] should serve a page that establishes a WebSocket connection with
  /// this process. That connection, once established, should be emitted via
  /// [future]. If [debug] is true, starts the browser in debug mode, with its
  /// debugger interfaces on and detected.
  ///
  /// Returns the browser manager, or throws an [ApplicationException] if a
  /// connection fails to be established.
  static Future<BrowserManager> start(TestPlatform platform, Uri url,
      Future<CompatibleWebSocket> future, {bool debug: false}) {
    var browser = _newBrowser(url, platform, debug: debug);

    var completer = new Completer();

    // TODO(nweiz): Gracefully handle the browser being killed before the
    // tests complete.
    browser.onExit.then((_) {
      throw new ApplicationException(
          "${platform.name} exited before connecting.");
    }).catchError((error, stackTrace) {
      if (completer.isCompleted) return;
      completer.completeError(error, stackTrace);
    });

    future.then((webSocket) {
      if (completer.isCompleted) return;
      completer.complete(new BrowserManager._(browser, platform, webSocket));
    }).catchError((error, stackTrace) {
      browser.close();
      if (completer.isCompleted) return;
      completer.completeError(error, stackTrace);
    });

    return completer.future.timeout(new Duration(seconds: 30), onTimeout: () {
      browser.close();
      throw new ApplicationException(
          "Timed out waiting for ${platform.name} to connect.");
    });
  }

  /// Starts the browser identified by [browser] and has it load [url].
  ///
  /// If [debug] is true, starts the browser in debug mode.
  static Browser _newBrowser(Uri url, TestPlatform browser,
      {bool debug: false}) {
    switch (browser) {
      case TestPlatform.dartium: return new Dartium(url, debug: debug);
      case TestPlatform.contentShell:
        return new ContentShell(url, debug: debug);
      case TestPlatform.chrome: return new Chrome(url);
      case TestPlatform.phantomJS: return new PhantomJS(url);
      case TestPlatform.firefox: return new Firefox(url);
      case TestPlatform.safari: return new Safari(url);
      case TestPlatform.internetExplorer: return new InternetExplorer(url);
      default:
        throw new ArgumentError("$browser is not a browser.");
    }
  }

  /// Creates a new BrowserManager that communicates with [browser] over
  /// [webSocket].
  BrowserManager._(this._browser, this._platform, CompatibleWebSocket webSocket)
      : _channel = new MultiChannel(
          webSocket.map(JSON.decode),
          mapSink(webSocket, JSON.encode)) {
    _environment = _loadBrowserEnvironment();
    _channel.stream.listen(_onMessage, onDone: close);
  }

  /// Loads [_BrowserEnvironment].
  Future<_BrowserEnvironment> _loadBrowserEnvironment() async {
    var observatoryUrl;
    if (_platform.isDartVM) observatoryUrl = await _browser.observatoryUrl;
    return new _BrowserEnvironment(this, observatoryUrl);
  }

  /// Tells the browser the load a test suite from the URL [url].
  ///
  /// [url] should be an HTML page with a reference to the JS-compiled test
  /// suite. [path] is the path of the original test suite file, which is used
  /// for reporting. [metadata] is the parsed metadata for the test suite.
  ///
  /// If [mapper] is passed, it's used to map stack traces for errors coming
  /// from this test suite.
  Future<RunnerSuite> loadSuite(String path, Uri url, Metadata metadata,
      {StackTraceMapper mapper}) async {
    url = url.replace(fragment: Uri.encodeFull(JSON.encode({
      "metadata": metadata.serialize(),
      "browser": _platform.identifier
    })));

    // The stream may close before emitting a value if the browser is killed
    // prematurely (e.g. via Control-C).
    var suiteVirtualChannel = _channel.virtualChannel();
    var suiteId = _suiteId++;
    var suiteChannel;

    closeIframe() {
      if (_closed) return;
      suiteChannel.sink.close();
      _channel.sink.add({
        "command": "closeSuite",
        "id": suiteId
      });
    }

    var response = await _pool.withResource(() {
      _channel.sink.add({
        "command": "loadSuite",
        "url": url.toString(),
        "id": _suiteId++,
        "channel": suiteVirtualChannel.id
      });

      // Create a nested MultiChannel because the iframe will be using a channel
      // wrapped within the host's channel.
      suiteChannel = new MultiChannel(
          suiteVirtualChannel.stream, suiteVirtualChannel.sink);

      var completer = new Completer();
      suiteChannel.stream.listen((response) {
        if (response["type"] == "print") {
          print(response["line"]);
        } else {
          completer.complete(response);
        }
      }, onDone: () {
        if (!completer.isCompleted) completer.complete();
      });

      return completer.future.timeout(new Duration(minutes: 1), onTimeout: () {
        throw new LoadException(
            path,
            "Timed out waiting for the test suite to connect on "
                "${_platform.name}.");
      });
    });

    if (response == null) {
      closeIframe();
      throw new LoadException(
          path, "Connection closed before test suite loaded.");
    }

    if (response["type"] == "loadException") {
      closeIframe();
      throw new LoadException(path, response["message"]);
    }

    if (response["type"] == "error") {
      closeIframe();
      var asyncError = RemoteException.deserialize(response["error"]);
      await new Future.error(
          new LoadException(path, asyncError.error),
          asyncError.stackTrace);
    }

    return new RunnerSuite(await _environment, response["tests"].map((test) {
      var testMetadata = new Metadata.deserialize(test['metadata']);
      var testChannel = suiteChannel.virtualChannel(test['channel']);
      return new IframeTest(test['name'], testMetadata, testChannel,
          mapper: mapper);
    }), platform: _platform, metadata: metadata, path: path,
        onClose: () => closeIframe());
  }

  /// An implementation of [Environment.displayPause].
  CancelableFuture _displayPause() {
    if (_pauseCompleter != null) return _pauseCompleter.future;

    _pauseCompleter = new CancelableCompleter(() {
      _channel.sink.add({"command": "resume"});
      _pauseCompleter = null;
    });

    _channel.sink.add({"command": "displayPause"});
    return _pauseCompleter.future.whenComplete(() {
      _pauseCompleter = null;
    });
  }

  /// The callback for handling messages received from the host page.
  void _onMessage(Map message) {
    assert(message["command"] == "resume");
    if (_pauseCompleter == null) return;
    _pauseCompleter.complete();
  }

  /// Closes the manager and releases any resources it owns, including closing
  /// the browser.
  Future close() => _closeMemoizer.runOnce(() {
    _closed = true;
    if (_pauseCompleter != null) _pauseCompleter.complete();
    _pauseCompleter = null;
    return _browser.close();
  });
  final _closeMemoizer = new AsyncMemoizer();
}

/// An implementation of [Environment] for the browser.
///
/// All methods forward directly to [BrowserManager].
class _BrowserEnvironment implements Environment {
  final BrowserManager _manager;

  final Uri observatoryUrl;

  _BrowserEnvironment(this._manager, this.observatoryUrl);

  CancelableFuture displayPause() => _manager._displayPause();
}
