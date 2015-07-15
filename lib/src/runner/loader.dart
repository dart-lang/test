// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.loader;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../backend/invoker.dart';
import '../backend/metadata.dart';
import '../backend/suite.dart';
import '../backend/test_platform.dart';
import '../util/async_thunk.dart';
import '../util/dart.dart' as dart;
import '../util/io.dart';
import '../util/remote_exception.dart';
import '../utils.dart';
import 'browser/server.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'parse_metadata.dart';
import 'vm/isolate_test.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// All platforms for which tests should be loaded.
  final List<TestPlatform> _platforms;

  /// Whether to enable colors for Dart compilation.
  final bool _color;

  /// Whether raw JavaScript stack traces should be used for tests that are
  /// compiled to JavaScript.
  final bool _jsTrace;

  /// Global metadata that applies to all test suites.
  final Metadata _metadata;

  /// The root directory that will be served for browser tests.
  final String _root;

  /// The package root to use for loading tests.
  final String _packageRoot;

  /// The URL for the `pub serve` instance to use to load tests.
  ///
  /// This is `null` if tests should be loaded from the filesystem.
  final Uri _pubServeUrl;

  /// All suites that have been created by the loader.
  final _suites = new Set<Suite>();

  /// The server that serves browser test pages.
  ///
  /// This is lazily initialized the first time it's accessed.
  Future<BrowserServer> get _browserServer {
    return _browserServerThunk.run(() {
      return BrowserServer.start(
          root: _root,
          packageRoot: _packageRoot,
          pubServeUrl: _pubServeUrl,
          color: _color,
          jsTrace: _jsTrace);
    });
  }
  final _browserServerThunk = new AsyncThunk<BrowserServer>();

  /// The thunk for running [close] exactly once.
  final _closeThunk = new AsyncThunk();

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
  /// [metadata] is the global metadata for all test suites.
  ///
  /// If the package root doesn't exist, throws an [ApplicationException].
  Loader(Iterable<TestPlatform> platforms, {String root, String packageRoot,
        Uri pubServeUrl, bool color: false, bool jsTrace: false,
        Metadata metadata})
      : _platforms = platforms.toList(),
        _pubServeUrl = pubServeUrl,
        _root = root == null ? p.current : root,
        _packageRoot = packageRootFor(root, packageRoot),
        _color = color,
        _jsTrace = jsTrace,
        _metadata = metadata == null ? new Metadata() : metadata;

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that end in "_test.dart". Any tests that
  /// fail to load will be emitted as [LoadException]s.
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual [Suite]s
  /// defined in the file.
  Stream<LoadSuite> loadDir(String dir) {
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
  /// This emits [LoadSuite]s that must then be run to emit the actual [Suite]s
  /// defined in the file.
  ///
  /// This will emit a [LoadException] if the file fails to load.
  Stream<LoadSuite> loadFile(String path) async* {
    var suiteMetadata;
    try {
      suiteMetadata = parseMetadata(path);
    } on AnalyzerErrorGroup catch (_) {
      // Ignore the analyzer's error, since its formatting is much worse than
      // the VM's or dart2js's.
      suiteMetadata = new Metadata();
    } on FormatException catch (error, stackTrace) {
      yield new LoadSuite.forLoadException(
          new LoadException(path, error), stackTrace: stackTrace);
      return;
    }
    suiteMetadata = _metadata.merge(suiteMetadata);

    if (_pubServeUrl != null && !p.isWithin('test', path)) {
      yield new LoadSuite.forLoadException(new LoadException(
          path, 'When using "pub serve", all test files must be in test/.'));
      return;
    }

    for (var platform in _platforms) {
      if (!suiteMetadata.testOn.evaluate(platform, os: currentOS)) continue;

      var metadata = suiteMetadata.forPlatform(platform, os: currentOS);

      // Don't load a skipped suite.
      if (metadata.skip) {
        yield new LoadSuite.forSuite(new Suite([
          new LocalTest(path, metadata, () {})
        ], path: path, platform: platform, metadata: metadata));
        continue;
      }

      var name = (platform.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, () {
        return platform == TestPlatform.vm
            ? _loadVmFile(path, metadata)
            : _loadBrowserFile(path, platform, metadata);
      }, platform: platform);
    }
  }

  /// Load the test suite at [path] in [platform].
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<Suite> _loadBrowserFile(String path, TestPlatform platform,
        Metadata metadata) async =>
      (await _browserServer).loadSuite(path, platform, metadata);

  /// Load the test suite at [path] in VM isolate.
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<Suite> _loadVmFile(String path, Metadata metadata) async {
    var receivePort = new ReceivePort();

    var isolate;
    try {
      if (_pubServeUrl != null) {
        var url = _pubServeUrl.resolveUri(
            p.toUri(p.relative(path, from: 'test') + '.vm_test.dart'));

        // TODO(nweiz): Remove new Future.sync() once issue 23498 has been fixed
        // in two stable versions.
        await new Future.sync(() async {
          try {
            isolate = await dart.spawnUri(url, {
              'reply': receivePort.sendPort,
              'metadata': metadata.serialize()
            }, checked: true);
          } on IsolateSpawnException catch (error) {
            if (error.message.contains("OS Error: Connection refused") ||
                error.message.contains("The remote computer refused")) {
              throw new LoadException(path,
                  "Error getting $url: Connection refused\n"
                  'Make sure "pub serve" is running.');
            } else if (error.message.contains("404 Not Found")) {
              throw new LoadException(path,
                  "Error getting $url: 404 Not Found\n"
                  'Make sure "pub serve" is serving the test/ directory.');
            }

            throw new LoadException(path, error);
          }
        });
      } else {
        isolate = await dart.runInIsolate('''
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
        }, packageRoot: p.toUri(_packageRoot), checked: true);
      }
    } catch (error, stackTrace) {
      receivePort.close();
      if (error is LoadException) rethrow;
      await new Future.error(new LoadException(path, error), stackTrace);
    }

    var completer = new Completer();

    var subscription = receivePort.listen((response) {
      if (response["type"] == "print") {
        print(response["line"]);
      } else if (response["type"] == "loadException") {
        isolate.kill();
        completer.completeError(
            new LoadException(path, response["message"]),
            new Trace.current());
      } else if (response["type"] == "error") {
        isolate.kill();
        var asyncError = RemoteException.deserialize(response["error"]);
        completer.completeError(
            new LoadException(path, asyncError.error),
            asyncError.stackTrace);
      } else {
        assert(response["type"] == "success");
        completer.complete(response["tests"]);
      }
    });

    try {
      var suite = new Suite((await completer.future).map((test) {
        var testMetadata = new Metadata.deserialize(test['metadata']);
        return new IsolateTest(test['name'], testMetadata, test['sendPort']);
      }),
          metadata: metadata,
          path: path,
          platform: TestPlatform.vm,
          os: currentOS,
          onClose: isolate.kill);
      _suites.add(suite);
      return suite;
    } finally {
      subscription.cancel();
    }
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() {
    return _closeThunk.run(() async {
      await Future.wait(_suites.map((suite) => suite.close()));
      _suites.clear();

      if (!_browserServerThunk.hasRun) return;
      await (await _browserServer).close();
    });
  }
}
