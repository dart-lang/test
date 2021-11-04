// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test_core/src/runner/application_exception.dart'; // ignore: implementation_imports
import 'package:test_core/src/util/errors.dart'; // ignore: implementation_imports
import 'package:typed_data/typed_data.dart';

/// An interface for running browser instances.
///
/// This is intentionally coarse-grained: browsers are controlled primary from
/// inside a single tab. Thus this interface only provides support for closing
/// the browser and seeing if it closes itself.
///
/// Any errors starting or running the browser process are reported through
/// [onExit].
abstract class Browser {
  String get name;

  /// The Observatory URL for this browser.
  ///
  /// This will complete to `null` for browsers that aren't running the Dart VM,
  /// or if the Observatory URL can't be found.
  Future<Uri?> get observatoryUrl async => null;

  /// The remote debugger URL for this browser.
  ///
  /// This will  complete to `null` for browsers that don't support remote
  /// debugging, or if the remote debugging URL can't be found.
  Future<Uri?> get remoteDebuggerUrl async => null;

  /// The underlying process.
  ///
  /// This will fire once the process has started successfully.
  Future<Process> get _process => _processCompleter.future;
  final _processCompleter = Completer<Process>();

  /// Whether [close] has been called.
  var _closed = false;

  /// A future that completes when the browser exits.
  ///
  /// If there's a problem starting or running the browser, this will complete
  /// with an error.
  Future<void> get onExit => _onExitCompleter.future;
  final _onExitCompleter = Completer<void>();

  /// Standard IO streams for the underlying browser process.
  final _ioSubscriptions = <StreamSubscription<List<int>>>[];

  final output = Uint8Buffer();

  /// Creates a new browser.
  ///
  /// This is intended to be called by subclasses. They pass in [startBrowser],
  /// which asynchronously returns the browser process. Any errors in
  /// [startBrowser] (even those raised asynchronously after it returns) are
  /// piped to [onExit] and will cause the browser to be killed.
  Browser(Future<Process> Function() startBrowser) {
    // Don't return a Future here because there's no need for the caller to wait
    // for the process to actually start. They should just wait for the HTTP
    // request instead.
    runZonedGuarded(() async {
      var process = await startBrowser();
      _processCompleter.complete(process);

      void drainOutput(Stream<List<int>> stream) {
        try {
          _ioSubscriptions
              .add(stream.listen(output.addAll, cancelOnError: true));
        } on StateError catch (_) {}
      }

      // If we don't drain the stdout and stderr the process can hang.
      drainOutput(process.stdout);
      drainOutput(process.stderr);

      var exitCode = await process.exitCode;

      // This hack dodges an otherwise intractable race condition. When the user
      // presses Control-C, the signal is sent to the browser and the test
      // runner at the same time. It's possible for the browser to exit before
      // the [Browser.close] is called, which would trigger the error below.
      //
      // A negative exit code signals that the process exited due to a signal.
      // However, it's possible that this signal didn't come from the user's
      // Control-C, in which case we do want to throw the error. The only way to
      // resolve the ambiguity is to wait a brief amount of time and see if this
      // browser is actually closed.
      if (!_closed && exitCode < 0) {
        await Future.delayed(Duration(milliseconds: 200));
      }

      if (!_closed && exitCode != 0) {
        var outputString = utf8.decode(output);
        var message = '$name failed with exit code $exitCode.';
        if (outputString.isNotEmpty) {
          message += '\nStandard output:\n$outputString';
        }

        throw ApplicationException(message);
      }

      _onExitCompleter.complete();
    }, (error, stackTrace) {
      // Ignore any errors after the browser has been closed.
      if (_closed) return;

      // Make sure the process dies even if the error wasn't fatal.
      _process.then((process) => process.kill());

      if (_onExitCompleter.isCompleted) return;
      _onExitCompleter.completeError(
          ApplicationException(
              'Failed to run $name: ${getErrorMessage(error)}.'),
          stackTrace);
    });
  }

  /// Kills the browser process.
  ///
  /// Returns the same [Future] as [onExit], except that it won't emit
  /// exceptions.
  Future<void> close() async {
    _closed = true;

    // If we don't manually close the stream the test runner can hang.
    // For example this happens with Chrome Headless.
    // See SDK issue: https://github.com/dart-lang/sdk/issues/31264
    for (var stream in _ioSubscriptions) {
      unawaited(stream.cancel());
    }

    (await _process).kill();

    // Swallow exceptions. The user should explicitly use [onExit] for these.
    return onExit.onError((_, __) {});
  }
}
