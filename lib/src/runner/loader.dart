// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.loader;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/analyzer.dart';
import 'package:path/path.dart' as p;

import '../backend/metadata.dart';
import '../backend/suite.dart';
import '../backend/test_platform.dart';
import '../util/dart.dart';
import '../util/io.dart';
import '../util/remote_exception.dart';
import '../utils.dart';
import 'browser/server.dart';
import 'load_exception.dart';
import 'parse_metadata.dart';
import 'vm/isolate_test.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// All platforms for which tests should be loaded.
  final List<TestPlatform> _platforms;

  /// Whether to enable colors for Dart compilation.
  final bool _color;

  /// The package root to use for loading tests, or `null` to use the automatic
  /// root.
  final String _packageRoot;

  /// All isolates that have been spun up by the loader.
  final _isolates = new Set<Isolate>();

  /// The server that serves browser test pages.
  ///
  /// This is lazily initialized the first time it's accessed.
  Future<BrowserServer> get _browserServer {
    if (_browserServerCompleter == null) {
      _browserServerCompleter = new Completer();
      BrowserServer.start(packageRoot: _packageRoot, color: _color)
          .then(_browserServerCompleter.complete)
          .catchError(_browserServerCompleter.completeError);
    }
    return _browserServerCompleter.future;
  }
  Completer<BrowserServer> _browserServerCompleter;

  /// Creates a new loader.
  ///
  /// If [packageRoot] is passed, it's used as the package root for all loaded
  /// tests. Otherwise, the `packages/` directories next to the test entrypoints
  /// will be used.
  ///
  /// If [color] is true, console colors will be used when compiling Dart.
  Loader(Iterable<TestPlatform> platforms, {String packageRoot,
        bool color: false})
      : _platforms = platforms.toList(),
        _packageRoot = packageRoot,
        _color = color;

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that end in "_test.dart".
  Future<List<Suite>> loadDir(String dir) {
    return Future.wait(new Directory(dir).listSync(recursive: true)
        .map((entry) {
      if (entry is! File) return new Future.value([]);
      if (!entry.path.endsWith("_test.dart")) return new Future.value([]);
      if (p.split(entry.path).contains('packages')) return new Future.value([]);

      // TODO(nweiz): Provide a way for the caller to gracefully handle some
      // suites failing to load without stopping the rest.
      return loadFile(entry.path);
    })).then((suites) => flatten(suites));
  }

  /// Loads a test suite from the file at [path].
  ///
  /// This will throw a [LoadException] if the file fails to load.
  Future<List<Suite>> loadFile(String path) {
    var metadata;
    try {
      metadata = parseMetadata(path);
    } on AnalyzerErrorGroup catch (_) {
      // Ignore the analyzer's error, since its formatting is much worse than
      // the VM's or dart2js's.
      metadata = new Metadata();
    } on FormatException catch (error) {
      throw new LoadException(path, error);
    }

    return Future.wait(_platforms.map((platform) {
      return new Future.sync(() {
        if (!metadata.testOn.evaluate(platform, os: currentOS)) return null;

        if (platform == TestPlatform.chrome) return _loadBrowserFile(path);
        assert(platform == TestPlatform.vm);
        return _loadVmFile(path);
      }).then((suite) =>
          suite == null ? null : suite.change(metadata: metadata));
    })).then((suites) => suites.where((suite) => suite != null).toList());
  }

  /// Load the test suite at [path] in a browser.
  Future<Suite> _loadBrowserFile(String path) =>
      _browserServer.then((browserServer) => browserServer.loadSuite(path));

  /// Load the test suite at [path] in VM isolate.
  Future<Suite> _loadVmFile(String path) {
    var packageRoot = packageRootFor(path, _packageRoot);
    var receivePort = new ReceivePort();
    return runInIsolate('''
import "package:unittest/src/runner/vm/isolate_listener.dart";

import "${p.toUri(p.absolute(path))}" as test;

void main(_, Map message) {
  var sendPort = message['reply'];
  IsolateListener.start(sendPort, () => test.main);
}
''', {
      'reply': receivePort.sendPort
    }, packageRoot: packageRoot)
        .catchError((error, stackTrace) {
      receivePort.close();
      return new Future.error(new LoadException(path, error), stackTrace);
    }).then((isolate) {
      _isolates.add(isolate);
      return receivePort.first;
    }).then((response) {
      if (response["type"] == "loadException") {
        return new Future.error(new LoadException(path, response["message"]));
      } else if (response["type"] == "error") {
        var asyncError = RemoteException.deserialize(response["error"]);
        return new Future.error(
            new LoadException(path, asyncError.error),
            asyncError.stackTrace);
      }

      return new Suite(response["tests"].map((test) {
        return new IsolateTest(test['name'], test['sendPort']);
      }), path: path, platform: "VM");
    });
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() {
    for (var isolate in _isolates) {
      isolate.kill();
    }
    _isolates.clear();

    if (_browserServerCompleter == null) return new Future.value();
    return _browserServer.then((browserServer) => browserServer.close());
  }
}
