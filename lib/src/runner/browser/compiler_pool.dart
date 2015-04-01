// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.compiler_pool;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../../util/io.dart';
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

  /// Creates a compiler pool that runs up to [parallel] instances of `dart2js`
  /// at once.
  ///
  /// If [parallel] isn't provided, it defaults to 4.
  ///
  /// If [color] is true, `dart2js` will be run with colors enabled.
  CompilerPool({int parallel, bool color: false})
      : _pool = new Pool(parallel == null ? 4 : parallel),
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
      return withTempDir((dir) {
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

        var args = ["--checked", wrapperPath, "--out=$jsPath"];

        if (packageRoot != null) {
          args.add("--package-root=${p.absolute(packageRoot)}");
        }

        if (_color) args.add("--enable-diagnostic-colors");

        return Process.start(dart2jsPath, args).then((process) {
          var compiler = new _Compiler(dartPath, process);

          if (_compilers.isEmpty) _showProcess(compiler);
          _compilers.add(compiler);

          return compiler.onDone;
        });
      });
    });
  }

  /// Mark [compiler] as the visible instance.
  ///
  /// This prints all [compiler]'s standard output and error.
  void _showProcess(_Compiler compiler) {
    print("Compiling ${compiler.path}...");

    // We wait for stdout and stderr to close and for exitCode to fire to ensure
    // that we're done printing everything about one process before we start the
    // next.
    Future.wait([
      compiler.process.stdout.listen(stdout.add).asFuture(),
      compiler.process.stderr.listen(stderr.add).asFuture(),
      compiler.process.exitCode.then((exitCode) {
        if (exitCode == 0) return;
        throw new LoadException(compiler.path, "dart2js failed.");
      })
    ]).then(compiler.onDoneCompleter.complete)
        .catchError(compiler.onDoneCompleter.completeError)
        .then((_) {
      _compilers.removeFirst();
      if (_compilers.isEmpty) return;

      var next = _compilers.first;

      // Wait a bit before printing the next progress in case the current one
      // threw an error that needs to be printed.
      Timer.run(() => _showProcess(next));
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
