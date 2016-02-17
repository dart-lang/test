// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pool/pool.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../backend/metadata.dart';
import '../../backend/test_platform.dart';
import '../../util/stack_trace_mapper.dart';
import '../application_exception.dart';
import '../environment.dart';
import '../plugin/platform_helpers.dart';
import '../runner_suite.dart';
import 'browser.dart';
import 'chrome.dart';
import 'content_shell.dart';
import 'dartium.dart';
import 'firefox.dart';
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
  MultiChannel _channel;

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
  int _suiteID = 0;

  /// Whether the channel to the browser has closed.
  bool _closed = false;

  /// The completer for [_BrowserEnvironment.displayPause].
  ///
  /// This will be `null` as long as the browser isn't displaying a pause
  /// screen.
  CancelableCompleter _pauseCompleter;

  /// The environment to attach to each suite.
  Future<_BrowserEnvironment> _environment;

  /// Controllers for every suite in this browser.
  ///
  /// These are used to mark suites as debugging or not based on the browser's
  /// pings.
  final _controllers = new Set<RunnerSuiteController>();

  // A timer that's reset whenever we receive a message from the browser.
  //
  // Because the browser stops running code when the user is actively debugging,
  // this lets us detect whether they're debugging reasonably accurately.
  RestartableTimer _timer;

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
      Future<WebSocketChannel> future, {bool debug: false}) {
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
      case TestPlatform.phantomJS: return new PhantomJS(url, debug: debug);
      case TestPlatform.firefox: return new Firefox(url);
      case TestPlatform.safari: return new Safari(url);
      case TestPlatform.internetExplorer: return new InternetExplorer(url);
      default:
        throw new ArgumentError("$browser is not a browser.");
    }
  }

  /// Creates a new BrowserManager that communicates with [browser] over
  /// [webSocket].
  BrowserManager._(this._browser, this._platform, WebSocketChannel webSocket) {
    // The duration should be short enough that the debugging console is open as
    // soon as the user is done setting breakpoints, but long enough that a test
    // doing a lot of synchronous work doesn't trigger a false positive.
    //
    // Start this canceled because we don't want it to start ticking until we
    // get some response from the iframe.
    _timer = new RestartableTimer(new Duration(seconds: 3), () {
      for (var controller in _controllers) {
        controller.setDebugging(true);
      }
    })..cancel();

    // Whenever we get a message, no matter which child channel it's for, we the
    // know browser is still running code which means the user isn't debugging.
    _channel = new MultiChannel(webSocket.transform(jsonDocument)
        .changeStream((stream) {
      return stream.map((message) {
        _timer.reset();
        for (var controller in _controllers) {
          controller.setDebugging(false);
        }

        return message;
      });
    }));

    _environment = _loadBrowserEnvironment();
    _channel.stream.listen(_onMessage, onDone: close);
  }

  /// Loads [_BrowserEnvironment].
  Future<_BrowserEnvironment> _loadBrowserEnvironment() async {
    var observatoryUrl;
    if (_platform.isDartVM) observatoryUrl = await _browser.observatoryUrl;

    var remoteDebuggerUrl;
    if (_platform.isHeadless) {
      remoteDebuggerUrl = await _browser.remoteDebuggerUrl;
    }

    return new _BrowserEnvironment(this, observatoryUrl, remoteDebuggerUrl);
  }

  /// Tells the browser the load a test suite from the URL [url].
  ///
  /// [url] should be an HTML page with a reference to the JS-compiled test
  /// suite. [path] is the path of the original test suite file, which is used
  /// for reporting. [metadata] is the parsed metadata for the test suite.
  ///
  /// If [mapper] is passed, it's used to map stack traces for errors coming
  /// from this test suite.
  Future<RunnerSuite> load(String path, Uri url, Metadata metadata,
      {StackTraceMapper mapper}) async {
    url = url.replace(fragment: Uri.encodeFull(JSON.encode({
      "metadata": metadata.serialize(),
      "browser": _platform.identifier
    })));

    var suiteID = _suiteID++;
    var controller;
    closeIframe() {
      if (_closed) return;
      _controllers.remove(controller);
      _channel.sink.add({
        "command": "closeSuite",
        "id": suiteID
      });
    }

    // The virtual channel will be closed when the suite is closed, in which
    // case we should unload the iframe.
    var suiteChannel = _channel.virtualChannel();
    var suiteChannelID = suiteChannel.id;
    suiteChannel = suiteChannel.transformStream(
        new StreamTransformer.fromHandlers(handleDone: (sink) {
          closeIframe();
          sink.close();
        }));

    return await _pool.withResource(() async {
      _channel.sink.add({
        "command": "loadSuite",
        "url": url.toString(),
        "id": suiteID,
        "channel": suiteChannelID
      });

      try {
        controller = await deserializeSuite(
            path, _platform, metadata, await _environment, suiteChannel,
            mapTrace: mapper?.mapStackTrace);
        _controllers.add(controller);
        return controller.suite;
      } catch (_) {
        closeIframe();
        rethrow;
      }
    });
  }

  /// An implementation of [Environment.displayPause].
  CancelableOperation _displayPause() {
    if (_pauseCompleter != null) return _pauseCompleter.operation;

    _pauseCompleter = new CancelableCompleter(onCancel: () {
      _channel.sink.add({"command": "resume"});
      _pauseCompleter = null;
    });

    _pauseCompleter.operation.value.whenComplete(() {
      _pauseCompleter = null;
    });

    _channel.sink.add({"command": "displayPause"});

    return _pauseCompleter.operation;
  }

  /// The callback for handling messages received from the host page.
  void _onMessage(Map message) {
    if (message["command"] == "ping") return;

    assert(message["command"] == "resume");
    if (_pauseCompleter == null) return;
    _pauseCompleter.complete();
  }

  /// Closes the manager and releases any resources it owns, including closing
  /// the browser.
  Future close() => _closeMemoizer.runOnce(() {
    _closed = true;
    _timer.cancel();
    if (_pauseCompleter != null) _pauseCompleter.complete();
    _pauseCompleter = null;
    _controllers.clear();
    return _browser.close();
  });
  final _closeMemoizer = new AsyncMemoizer();
}

/// An implementation of [Environment] for the browser.
///
/// All methods forward directly to [BrowserManager].
class _BrowserEnvironment implements Environment {
  final BrowserManager _manager;

  final supportsDebugging = true;

  final Uri observatoryUrl;

  final Uri remoteDebuggerUrl;

  _BrowserEnvironment(this._manager, this.observatoryUrl,
      this.remoteDebuggerUrl);

  CancelableOperation displayPause() => _manager._displayPause();
}
