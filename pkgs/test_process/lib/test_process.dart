// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A wrapper for [Process] that provides a convenient API for testing its
/// standard IO and interacting with it from a test.
///
/// If the test fails, this will automatically print out any stdout and stderr
/// from the process to aid debugging.
///
/// This may be extended to provide custom implementations of [stdoutStream] and
/// [stderrStream]. These will automatically be picked up by the [stdout] and
/// [stderr] queues, but the debug log will still contain the original output.
class TestProcess {
  /// The underlying process.
  final Process _process;

  /// A human-friendly description of this process.
  final String description;

  /// A [StreamQueue] that emits each line of stdout from the process.
  ///
  /// A copy of the underlying stream can be retrieved using [stdoutStream].
  late final StreamQueue<String> stdout = StreamQueue(stdoutStream());

  /// A [StreamQueue] that emits each line of stderr from the process.
  ///
  /// A copy of the underlying stream can be retrieved using [stderrStream].
  late final StreamQueue<String> stderr = StreamQueue(stderrStream());

  /// A splitter that can emit new copies of [stdout].
  final StreamSplitter<String> _stdoutSplitter;

  /// A splitter that can emit new copies of [stderr].
  final StreamSplitter<String> _stderrSplitter;

  /// The standard input sink for this process.
  IOSink get stdin => _process.stdin;

  /// A buffer of mixed stdout and stderr lines.
  final List<String> _log = <String>[];

  /// Whether [_log] has been passed to [printOnFailure] yet.
  bool _loggedOutput = false;

  /// Returns a [Future] which completes to the exit code of the process, once
  /// it completes.
  Future<int> get exitCode => _process.exitCode;

  /// The process ID of the process.
  int get pid => _process.pid;

  /// Completes to [_process]'s exit code if it's exited, otherwise completes to
  /// `null` immediately.
  Future<int?> get _exitCodeOrNull async => await exitCode
      .then<int?>((value) => value)
      .timeout(Duration.zero, onTimeout: () => null);

  /// Starts a process.
  ///
  /// [executable], [arguments], [workingDirectory], and [environment] have the
  /// same meaning as for [Process.start].
  ///
  /// [description] is a string description of this process; it defaults to the
  /// command-line invocation. [encoding] is the [Encoding] that will be used
  /// for the process's input and output; it defaults to [utf8].
  ///
  /// If [forwardStdio] is `true`, the process's stdout and stderr will be
  /// printed to the console as they appear. This is only intended to be set
  /// temporarily to help when debugging test failures.
  static Future<TestProcess> start(
      String executable, Iterable<String> arguments,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      String? description,
      Encoding encoding = utf8,
      bool forwardStdio = false}) async {
    var process = await Process.start(executable, arguments.toList(),
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell);

    if (description == null) {
      var humanExecutable = p.isWithin(p.current, executable)
          ? p.relative(executable)
          : executable;
      description = "$humanExecutable ${arguments.join(" ")}";
    }

    return TestProcess(process, description,
        encoding: encoding, forwardStdio: forwardStdio);
  }

  /// Creates a [TestProcess] for [process].
  ///
  /// The [description], [encoding], and [forwardStdio] are the same as those to
  /// [start].
  ///
  /// This is protected, which means it should only be called by subclasses.
  @protected
  TestProcess(Process process, this.description,
      {Encoding encoding = utf8, bool forwardStdio = false})
      : _process = process,
        _stdoutSplitter = StreamSplitter(process.stdout
            .transform(encoding.decoder)
            .transform(const LineSplitter())),
        _stderrSplitter = StreamSplitter(process.stderr
            .transform(encoding.decoder)
            .transform(const LineSplitter())) {
    addTearDown(_tearDown);
    expect(_process.exitCode.then((_) => _logOutput()), completes,
        reason: 'Process `$description` never exited.');

    // Listen eagerly so that the lines are interleaved properly between the two
    // streams.
    //
    // Call [split] explicitly because we don't want to log overridden
    // [stdoutStream] or [stderrStream] output.
    _stdoutSplitter.split().listen((line) {
      _heartbeat();
      if (forwardStdio) print(line);
      _log.add('    $line');
    });

    _stderrSplitter.split().listen((line) {
      _heartbeat();
      if (forwardStdio) print(line);
      _log.add('[e] $line');
    });
  }

  /// A callback that's run when the test completes.
  Future _tearDown() async {
    // If the process is already dead, do nothing.
    if (await _exitCodeOrNull != null) return;

    _process.kill(ProcessSignal.sigkill);

    // Log output now rather than waiting for the exitCode callback so that
    // it's visible even if we time out waiting for the process to die.
    await _logOutput();
  }

  /// Formats the contents of [_log] and passes them to [printOnFailure].
  Future _logOutput() async {
    if (_loggedOutput) return;
    _loggedOutput = true;

    var exitCodeOrNull = await _exitCodeOrNull;

    // Wait a timer tick to ensure that all available lines have been flushed to
    // [_log].
    await Future.delayed(Duration.zero);

    var buffer = StringBuffer();
    buffer.write('Process `$description` ');
    if (exitCodeOrNull == null) {
      buffer.writeln('was killed with SIGKILL in a tear-down. Output:');
    } else {
      buffer.writeln('exited with exitCode $exitCodeOrNull. Output:');
    }

    buffer.writeln(_log.join('\n'));
    printOnFailure(buffer.toString());
  }

  /// Returns a copy of [stdout] as a single-subscriber stream.
  ///
  /// Each time this is called, it will return a separate copy that will start
  /// from the beginning of the process.
  ///
  /// This can be overridden by subclasses to return a derived standard output
  /// stream. This stream will then be used for [stdout].
  Stream<String> stdoutStream() => _stdoutSplitter.split();

  /// Returns a copy of [stderr] as a single-subscriber stream.
  ///
  /// Each time this is called, it will return a separate copy that will start
  /// from the beginning of the process.
  ///
  /// This can be overridden by subclasses to return a derived standard output
  /// stream. This stream will then be used for [stderr].
  Stream<String> stderrStream() => _stderrSplitter.split();

  /// Sends [signal] to the process.
  ///
  /// This is meant for sending specific signals. If you just want to kill the
  /// process, use [kill] instead.
  ///
  /// Throws an [UnsupportedError] on Windows.
  void signal(ProcessSignal signal) {
    if (Platform.isWindows) {
      throw UnsupportedError(
          "TestProcess.signal() isn't supported on Windows.");
    }

    _process.kill(signal);
  }

  /// Kills the process (with SIGKILL on POSIX operating systems), and returns a
  /// future that completes once it's dead.
  ///
  /// If this is called after the process is already dead, it does nothing.
  Future kill() async {
    _process.kill(ProcessSignal.sigkill);
    await exitCode;
  }

  /// Waits for the process to exit, and verifies that the exit code matches
  /// [expectedExitCode] (if given).
  ///
  /// If this is called after the process is already dead, it verifies its
  /// existing exit code.
  Future shouldExit([expectedExitCode]) async {
    var exitCode = await this.exitCode;
    if (expectedExitCode == null) return;
    expect(exitCode, expectedExitCode,
        reason: 'Process `$description` had an unexpected exit code.');
  }

  /// Signal to the test runner that the test is still making progress and
  /// shouldn't time out.
  void _heartbeat() {
    // Interacting with the test runner's asynchronous expectation logic will
    // notify it that the test is alive.
    expectAsync0(() {})();
  }
}
