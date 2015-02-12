// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.loader;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'dart.dart';
import 'isolate_test.dart';
import 'suite.dart';

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
  /// This wil throw a [FileSystemException] if there's no `packages/` directory
  /// available for [path]. Any other load error will cause an
  /// [IsolateSpawnException] or a [RemoteException].
  Future<Suite> loadFile(String path) {
    // TODO(nweiz): Support browser tests.
    var packageRoot = _packageRoot == null
        ? p.join(p.dirname(path), 'packages')
        : _packageRoot;

    if (!new Directory(packageRoot).existsSync()) {
      throw new FileSystemException("Directory $packageRoot does not exist.");
    }

    var receivePort = new ReceivePort();
    return runInIsolate('''
import "package:unittest/src/vm_listener.dart";

import "${p.toUri(p.absolute(path))}" as test;

void main(_, Map message) {
  var sendPort = message['reply'];
  VmListener.start(sendPort, test.main);
}
''', {
      'reply': receivePort.sendPort
    }, packageRoot: packageRoot).then((isolate) {
      _isolates.add(isolate);
      return receivePort.first;
    }).then((tests) {
      return new Suite(path, tests.map((test) {
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
