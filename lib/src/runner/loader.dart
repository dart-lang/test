// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.loader;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../backend/suite.dart';
import '../util/dart.dart';
import '../util/io.dart';
import '../util/remote_exception.dart';
import 'vm/isolate_test.dart';
import 'load_exception.dart';

/// A class for finding test files and loading them into a runnable form.
class Loader {
  /// The package root to use for loading tests, or `null` to use the automatic
  /// root.
  final String _packageRoot;

  /// All isolates that have been spun up by the loader.
  final _isolates = new Set<Isolate>();

  /// Creates a new loader.
  ///
  /// If [packageRoot] is passed, it's used as the package root for all loaded
  /// tests. Otherwise, the `packages/` directories next to the test entrypoints
  /// will be used.
  Loader({String packageRoot})
      : _packageRoot = packageRoot;

  /// Loads all test suites in [dir].
  ///
  /// This will load tests from files that end in "_test.dart".
  Future<Set<Suite>> loadDir(String dir) {
    return Future.wait(new Directory(dir).listSync(recursive: true)
        .map((entry) {
      if (entry is! File) return new Future.value();
      if (!entry.path.endsWith("_test.dart")) return new Future.value();
      if (p.split(entry.path).contains('packages')) return new Future.value();

      // TODO(nweiz): Provide a way for the caller to gracefully handle some
      // isolates failing to load without stopping the rest.
      return loadFile(entry.path);
    })).then((suites) => suites.toSet()..remove(null));
  }

  /// Loads a test suite from the file at [path].
  ///
  /// This will throw a [LoadException] if the file fails to load.
  Future<Suite> loadFile(String path) {
    // TODO(nweiz): Support browser tests.
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

      return new Suite(path, response["tests"].map((test) {
        return new IsolateTest(test['name'], test['sendPort']);
      }));
    });
  }

  /// Closes the loader and releases all resources allocated by it.
  Future close() {
    for (var isolate in _isolates) {
      isolate.kill();
    }
    _isolates.clear();
    return new Future.value();
  }
}
