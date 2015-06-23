// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.compiler_pool;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../../util/async_thunk.dart';
import '../../util/io.dart';
import '../load_exception.dart';

/// A pool of `dart2js` instances.
///
/// This limits the number of compiler instances running concurrently.
class CompilerPool {
  /// The internal pool that controls the number of process running at once.
  final Pool _pool;

  /// Whether to enable colors on dart2js.
  final bool _color;

  /// The currently-active dart2js processes.
  final _processes = new Set<Process>();

  /// Whether [close] has been called.
  bool get _closed => _closeThunk.hasRun;

  /// The thunk for running [close] exactly once.
  final _closeThunk = new AsyncThunk();

  /// Creates a compiler pool that runs up to [concurrency] instances of
  /// `dart2js` at once.
  ///
  /// If [concurrency] isn't provided, it defaults to 4.
  ///
  /// If [color] is true, `dart2js` will be run with colors enabled.
  CompilerPool({int concurrency, bool color: false})
      : _pool = new Pool(concurrency == null ? 4 : concurrency),
        _color = color;

  /// Compile the Dart code at [dartPath] to [jsPath].
  ///
  /// This wraps the Dart code in the standard browser-testing wrapper. If
  /// [packageRoot] is provided, it's used as the package root for the
  /// compilation.
  ///
  /// The returned [Future] will complete once the `dart2js` process completes
  /// *and* all its output has been printed to the command line.
  Future compile(String dartPath, String jsPath, {String packageRoot}) {
    return _pool.withResource(() {
      if (_closed) return null;

      return withTempDir((dir) async {
        var wrapperPath = p.join(dir, "runInBrowser.dart");
        new File(wrapperPath).writeAsStringSync('''
import "package:test/src/runner/browser/iframe_listener.dart";

import "${p.toUri(p.absolute(dartPath))}" as test;

void main(_) {
  IframeListener.start(() => test.main);
}
''');

        var dart2jsPath = p.join(sdkDir, 'bin', 'dart2js');
        if (Platform.isWindows) dart2jsPath += '.bat';

        var args = ["--checked", wrapperPath, "--out=$jsPath", "--show-package-warnings"];

        if (packageRoot != null) {
          args.add("--package-root=${p.toUri(p.absolute(packageRoot))}");
        }

        if (_color) args.add("--enable-diagnostic-colors");

        var process = await Process.start(dart2jsPath, args);
        if (_closed) {
          process.kill();
          return;
        }

        _processes.add(process);

        /// Wait until the process is entirely done to print out any output.
        /// This can produce a little extra time for users to wait with no
        /// update, but it also avoids some really nasty-looking interleaved
        /// output. Write both stdout and stderr to the same buffer in case
        /// they're intended to be printed in order.
        var buffer = new StringBuffer();

        await Future.wait([
          _printOutputStream(process.stdout, buffer),
          _printOutputStream(process.stderr, buffer),
        ]);

        var exitCode = await process.exitCode;
        _processes.remove(process);
        if (_closed) return;

        if (buffer.isNotEmpty) print(buffer);

        if (exitCode != 0) {
          throw new LoadException(dartPath, "dart2js failed.");
        }
      });
    });
  }

  /// Sanitizes the bytes emitted by [stream], converts them to text, and writes
  /// them to [buffer].
  Future _printOutputStream(Stream<List<int>> stream, StringBuffer buffer) {
    return sanitizeForWindows(stream)
        .listen((data) => buffer.write(UTF8.decode(data))).asFuture();
  }

  /// Closes the compiler pool.
  ///
  /// This kills all currently-running compilers and ensures that no more will
  /// be started. It returns a [Future] that completes once all the compilers
  /// have been killed and all resources released.
  Future close() {
    return _closeThunk.run(() async {
      await Future.wait(_processes.map((process) async {
        process.kill();
        await process.exitCode;
      }));
    });
  }
}
