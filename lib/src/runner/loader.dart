// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.loader;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/analyzer.dart';
import 'package:path/path.dart' as p;

import '../backend/invoker.dart';
import '../backend/metadata.dart';
import '../backend/suite.dart';
import '../backend/test_platform.dart';
import '../util/dart.dart';
import '../util/io.dart';
import '../util/isolate_wrapper.dart';
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

  /// The root directory that will be served for browser tests.
  final String _root;

  /// The package root to use for loading tests.
  final String _packageRoot;

  /// The URL for the `pub serve` instance to use to load tests.
  ///
  /// This is `null` if tests should be loaded from the filesystem.
  final Uri _pubServeUrl;

  /// All isolates that have been spun up by the loader.
  final _isolates = new Set<IsolateWrapper>();

  /// The server that serves browser test pages.
  ///
  /// This is lazily initialized the first time it's accessed.
  Future<BrowserServer> get _browserServer {
    if (_browserServerCompleter == null) {
      _browserServerCompleter = new Completer();
      BrowserServer.start(
              root: _root,
              packageRoot: _packageRoot,
              pubServeUrl: _pubServeUrl,
              color: _color)
          .then(_browserServerCompleter.complete)
          .catchError(_browserServerCompleter.completeError);
    }
    return _browserServerCompleter.future;
  }
  Completer<BrowserServer> _browserServerCompleter;

  /// Creates a new loader.
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  ///
  /// If [packageRoot] is passed, it's used as the package root for all loaded
  /// tests. Otherwise, it's inferred from [root].
  ///
  /// If [pubServeUrl] is passed, tests will be loaded from the `pub serve`
  /// instance at that URL rather than from the filesystem.
  ///
  /// If [color] is true, console colors will be used when compiling Dart.
  ///
  /// If the package root doesn't exist, throws an [ApplicationException].
  Loader(Iterable<TestPlatform> platforms, {String root, String packageRoot,
        Uri pubServeUrl, bool color: false})
      : _platforms = platforms.toList(),
        _pubServeUrl = pubServeUrl,
        _root = root == null ? p.current : root,
        _packageRoot = packageRootFor(root, packageRoot),
        _color = color;

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that end in "_test.dart". Any tests that
  /// fail to load will be emitted as [LoadException]s.
  Stream<Suite> loadDir(String dir) {
    return mergeStreams(new Directory(dir).listSync(recursive: true)
        .map((entry) {
      if (entry is! File) return new Stream.fromIterable([]);

      if (!entry.path.endsWith("_test.dart")) {
        return new Stream.fromIterable([]);
      }

      if (p.split(entry.path).contains('packages')) {
         return new Stream.fromIterable([]);
      }

      return loadFile(entry.path);
    }));
  }

  /// Loads a test suite from the file at [path].
  ///
  /// This will emit a [LoadException] if the file fails to load.
  Stream<Suite> loadFile(String path) {
    var metadata;
    try {
      metadata = parseMetadata(path);
    } on AnalyzerErrorGroup catch (_) {
      // Ignore the analyzer's error, since its formatting is much worse than
      // the VM's or dart2js's.
      metadata = new Metadata();
    } on FormatException catch (error, stackTrace) {
      return new Stream.fromFuture(
          new Future.error(new LoadException(path, error), stackTrace));
    }

    var controller = new StreamController();
    Future.forEach(_platforms, (platform) {
      if (!metadata.testOn.evaluate(platform, os: currentOS)) {
        return null;
      }

      // Don't load a skipped suite.
      if (metadata.skip) {
        controller.add(new Suite([
          new LocalTest(path, metadata, () {})
        ], path: path, platform: platform.name, metadata: metadata));
        return null;
      }

      return new Future.sync(() {
        if (_pubServeUrl != null && !p.isWithin('test', path)) {
          throw new LoadException(path,
              'When using "pub serve", all test files must be in test/.');
        }

        if (platform == TestPlatform.vm) return _loadVmFile(path, metadata);
        assert(platform.isBrowser);
        return _loadBrowserFile(path, platform, metadata);
      }).then((suite) {
        if (suite == null) return;

        controller.add(suite.filter(platform, os: currentOS));
      }).catchError(controller.addError);
    }).then((_) => controller.close());

    return controller.stream;
  }

  /// Load the test suite at [path] in [platform].
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<Suite> _loadBrowserFile(String path, TestPlatform platform,
        Metadata metadata) =>
      _browserServer.then((browserServer) =>
          browserServer.loadSuite(path, platform, metadata));

  /// Load the test suite at [path] in VM isolate.
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<Suite> _loadVmFile(String path, Metadata metadata) {
    var receivePort = new ReceivePort();

    return new Future.sync(() {
      if (_pubServeUrl != null) {
        var url = _pubServeUrl.resolve(
            p.relative(path, from: 'test') + '.vm_test.dart');
        return Isolate.spawnUri(url, [], {
          'reply': receivePort.sendPort,
          'metadata': metadata.serialize()
        }).then((isolate) => new IsolateWrapper(isolate, () {}))
            .catchError((error, stackTrace) {
          if (error is! IsolateSpawnException) throw error;

          if (error.message.contains("OS Error: Connection refused")) {
            throw new LoadException(path,
                "Error getting $url: Connection refused\n"
                'Make sure "pub serve" is running.');
          } else if (error.message.contains("404 Not Found")) {
            throw new LoadException(path,
                "Error getting $url: 404 Not Found\n"
                'Make sure "pub serve" is serving the test/ directory.');
          }

          throw new LoadException(path, error);
        });
      } else {
        return runInIsolate('''
import "package:test/src/backend/metadata.dart";
import "package:test/src/runner/vm/isolate_listener.dart";

import "${p.toUri(p.absolute(path))}" as test;

void main(_, Map message) {
  var sendPort = message['reply'];
  var metadata = new Metadata.deserialize(message['metadata']);
  IsolateListener.start(sendPort, metadata, () => test.main);
}
''', {
          'reply': receivePort.sendPort,
          'metadata': metadata.serialize()
        }, packageRoot: _packageRoot);
      }
    }).catchError((error, stackTrace) {
      receivePort.close();
      if (error is LoadException) throw error;
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
        var testMetadata = new Metadata.deserialize(test['metadata']);
        return new IsolateTest(test['name'], testMetadata, test['sendPort']);
      }), metadata: metadata, path: path, platform: "VM");
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
