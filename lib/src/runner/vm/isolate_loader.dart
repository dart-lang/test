// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.isolate_loader;

import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../../backend/metadata.dart';
import '../../backend/test_platform.dart';
import '../../util/dart.dart' as dart;
import '../../util/io.dart';
import '../../util/remote_exception.dart';
import '../configuration.dart';
import '../load_exception.dart';
import '../runner_suite.dart';
import 'environment.dart';
import 'isolate_test.dart';

/// A class for loading test files in an Isolate.
class IsolateLoader {
  /// The test runner configuration.
  final Configuration _config;

  /// All suites that have been created by the loader.
  final _suites = new Set<RunnerSuite>();

  /// Creates a new loader that loads tests on platforms defined in [_config].
  IsolateLoader(this._config);

  /// Load the test suite at [path] in VM isolate.
  ///
  /// [metadata] is the suite-level metadata for the test.
  Future<RunnerSuite> loadSuite(String path, Metadata metadata) async {
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
        completer.complete(response["tests"]);
      }
    });

    try {
      var suite = new RunnerSuite(const VMEnvironment(),
          (await completer.future).map((test) {
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
  Future close() async {
    await Future.wait(_suites.map((suite) => suite.close()));
    _suites.clear();
  }
}
