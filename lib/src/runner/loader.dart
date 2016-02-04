// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/analyzer.dart' hide Configuration;
import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../backend/group.dart';
import '../backend/metadata.dart';
import '../backend/test.dart';
import '../backend/test_platform.dart';
import '../util/dart.dart' as dart;
import '../util/io.dart';
import '../util/remote_exception.dart';
import '../utils.dart';
import 'browser/server.dart';
import 'configuration.dart';
import 'hack_load_vm_file_hook.dart';
import 'load_exception.dart';
import 'load_suite.dart';
import 'parse_metadata.dart';
import 'runner_suite.dart';
import 'vm/environment.dart';
import 'vm/isolate_test.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// The test runner configuration.
  final Configuration _config;

  /// The root directory that will be served for browser tests.
  final String _root;

  /// All suites that have been created by the loader.
  final _suites = new Set<RunnerSuite>();

  /// The server that serves browser test pages.
  ///
  /// This is lazily initialized the first time it's accessed.
  Future<BrowserServer> get _browserServer {
    return _browserServerMemo.runOnce(() {
      return BrowserServer.start(_config, root: _root);
    });
  }
  final _browserServerMemo = new AsyncMemoizer<BrowserServer>();

  /// The memoizer for running [close] exactly once.
  final _closeMemo = new AsyncMemoizer();

  /// Creates a new loader that loads tests on platforms defined in [_config].
  ///
  /// [root] is the root directory that will be served for browser tests. It
  /// defaults to the working directory.
  Loader(this._config, {String root})
      : _root = root == null ? p.current : root;

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that match the configuration's filename
  /// glob. Any tests that fail to load will be emitted as [LoadException]s.
  ///
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
  Stream<LoadSuite> loadDir(String dir) {
    return mergeStreams(new Directory(dir).listSync(recursive: true)
        .map((entry) {
      if (entry is! File) return new Stream.fromIterable([]);

      if (!_config.filename.matches(p.basename(entry.path))) {
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
  /// This emits [LoadSuite]s that must then be run to emit the actual
  /// [RunnerSuite]s defined in the file.
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
    suiteMetadata = _config.metadata.merge(suiteMetadata);

    if (_config.pubServeUrl != null && !p.isWithin('test', path)) {
      yield new LoadSuite.forLoadException(new LoadException(
          path, 'When using "pub serve", all test files must be in test/.'));
      return;
    }

    for (var platform in _config.platforms) {
      if (!suiteMetadata.testOn.evaluate(platform, os: currentOS)) continue;

      var metadata = suiteMetadata.forPlatform(platform, os: currentOS);

      // Don't load a skipped suite.
      if (metadata.skip) {
        yield new LoadSuite.forSuite(new RunnerSuite(
            const VMEnvironment(),
            new Group.root([], metadata: metadata),
            path: path, platform: platform));
        continue;
      }

      var name = (platform.isJS ? "compiling " : "loading ") + path;
      yield new LoadSuite(name, () {
        return platform == TestPlatform.vm
            ? _loadVmFile(path, metadata)
            : _loadBrowserFile(path, platform, metadata);
      }, path: path, platform: platform);
    }
  }

  /// Load the test suite at [path] in [platform].
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<RunnerSuite> _loadBrowserFile(String path, TestPlatform platform,
        Metadata metadata) async =>
      (await _browserServer).loadSuite(path, platform, metadata);

  /// Load the test suite at [path] in VM isolate.
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<RunnerSuite> _loadVmFile(String path, Metadata metadata) async {
    if (loadVMFileHook != null) {
      var suite = await loadVMFileHook(path, metadata, _config);
      _suites.add(suite);
      return suite;
    }

    var receivePort = new ReceivePort();

    var isolate;
    try {
      if (_config.pubServeUrl != null) {
        var url = _config.pubServeUrl.resolveUri(
            p.toUri(p.relative(path, from: 'test') + '.vm_test.dart'));

        try {
          isolate = await Isolate.spawnUri(url, [], {
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
        }, packageRoot: p.toUri(_config.packageRoot), checked: true);
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
        completer.complete(response["root"]);
      }
    });

    try {
      var suite = new RunnerSuite(
          const VMEnvironment(),
          _deserializeGroup(await completer.future),
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

  /// Deserializes [group] into a concrete [Group] class.
  Group _deserializeGroup(Map group) {
    var metadata = new Metadata.deserialize(group['metadata']);
    return new Group(group['name'], group['entries'].map((entry) {
      if (entry['type'] == 'group') return _deserializeGroup(entry);
      return _deserializeTest(entry);
    }),
        metadata: metadata,
        setUpAll: _deserializeTest(group['setUpAll']),
        tearDownAll: _deserializeTest(group['tearDownAll']));
  }

  /// Deserializes [test] into a concrete [Test] class.
  ///
  /// Returns `null` if [test] is `null`.
  Test _deserializeTest(Map test) {
    if (test == null) return null;

    var metadata = new Metadata.deserialize(test['metadata']);
    return new IsolateTest(test['name'], metadata, test['sendPort']);
  }

  /// Close all the browsers that the loader currently has open.
  ///
  /// Note that this doesn't close the loader itself. Browser tests can still be
  /// loaded, they'll just spawn new browsers.
  Future closeBrowsers() async {
    if (!_browserServerMemo.hasRun) return;
    await (await _browserServer).closeBrowsers();
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() {
    return _closeMemo.runOnce(() async {
      await Future.wait(_suites.map((suite) => suite.close()));
      _suites.clear();

      if (!_browserServerMemo.hasRun) return;
      await (await _browserServer).close();
    });
  }
}
