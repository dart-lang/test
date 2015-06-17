// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.compiler_pool;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../../util/async_thunk.dart';
import '../../util/io.dart';
import '../../utils.dart';
import '../load_exception.dart';

/// A pool of `dart2js` instances.
///
/// This limits the number of compiler instances running concurrently. It also
/// ensures that their output doesn't intermingle; only one instance is
/// "visible" (that is, having its output printed) at a time, and the other
/// instances' output is buffered until it's their turn to be visible.
class CompilerPool {
  /// The internal pool that controls the number of process running at once.
  final Pool _pool;

  /// Whether to enable colors on dart2js.
  final bool _color;

  /// The currently-active compilers.
  ///
  /// The first one is the only visible the compiler; the rest will become
  /// visible in queue order. Note that some of these processes may actually
  /// have already exited; they're kept around so that their output can be
  /// emitted once they become visible.
  final _compilers = new Queue<_Compiler>();

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
        var compiler = new _Compiler(dartPath, process);

        if (_compilers.isEmpty) _showProcess(compiler);
        _compilers.add(compiler);

        await compiler.onDone;
      });
    });
  }

  /// Mark [compiler] as the visible instance.
  ///
  /// This prints all [compiler]'s standard output and error.
  void _showProcess(_Compiler compiler) {
    print("Compiling ${compiler.path}...");

    invoke(() async {
      try {
        // We wait for stdout and stderr to close and for exitCode to fire to
        // ensure that we're done printing everything about one process before
        // we start the next.
        await Future.wait([
          sanitizeForWindows(compiler.process.stdout).listen(stdout.add)
              .asFuture(),
          sanitizeForWindows(compiler.process.stderr).listen(stderr.add)
              .asFuture(),
          compiler.process.exitCode.then((exitCode) {
            if (exitCode == 0 || _closed) return;
            throw new LoadException(compiler.path, "dart2js failed.");
          })
        ]);

        if (_closed) return;
        compiler.onDoneCompleter.complete();
      } catch (error, stackTrace) {
        if (_closed) return;
        compiler.onDoneCompleter.completeError(error, stackTrace);
      }

      _compilers.removeFirst();
      if (_compilers.isEmpty) return;

      var next = _compilers.first;

      // Wait a bit before printing the next process in case the current one
      // threw an error that needs to be printed.
      Timer.run(() => _showProcess(next));
    });
  }

  /// Closes the compiler pool.
  ///
  /// This kills all currently-running compilers and ensures that no more will
  /// be started. It returns a [Future] that completes once all the compilers
  /// have been killed and all resources released.
  Future close() {
    return _closeThunk.run(() async {
      await Future.wait(_compilers.map((compiler) async {
        compiler.process.kill();
        await compiler.process.exitCode;
        compiler.onDoneCompleter.complete();
      }));

      _compilers.clear();
    });
  }
}

/// A running instance of `dart2js`.
class _Compiler {
  /// The path of the Dart file being compiled.
  final String path;

  /// The underlying process.
  final Process process;

  /// A future that will complete once this instance has finished running and
  /// all its output has been printed.
  Future get onDone => onDoneCompleter.future;
  final onDoneCompleter = new Completer();

  _Compiler(this.path, this.process);
}
