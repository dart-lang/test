// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import '../backend/remote_exception.dart';

/// An optional fallback handler invoked when [globalSetup] is called outside
/// of the full test runner (for instance, when running a test file directly via
/// `dart <test_file>.dart`).
Future<Object?> Function(Uri uri)? globalSetupStandaloneFallback;

/// Runs a global setup Dart script at [uri] on the host test runner if it
/// has not yet run, and returns its result.
///
/// If multiple test suites or tests invoke [globalSetup] with the same [uri],
/// the script runs only once and all callers receive the same cached result.
///
/// The Dart file at [uri] must define a top-level `setUp()` function that
/// returns a JSON-encodable value (or `Future` of one).
///
/// [uri] is resolved according to the following rules:
/// * **`package:` URIs** (e.g. `Uri.parse('package:my_pkg/test_helpers.dart')`):
///   Resolved using the package configuration.
/// * **Root-relative URIs** (paths beginning with `/`, e.g. `Uri.parse('/test/setup.dart')`):
///   Interpreted relative to the root of the package (the directory containing `pubspec.yaml`).
/// * **Relative URIs** (paths without a scheme and without a leading `/`, e.g. `Uri.parse('setup.dart')` or `Uri.parse('../setup.dart')`):
///   Interpreted relative to the directory containing the test suite file being executed.
///   Note: When calling [globalSetup] from a shared helper library imported by tests in different directories,
///   prefer root-relative (`/test/...`) or `package:` URIs so the path resolves consistently regardless of which
///   test file imports the helper.
/// * **`file:` URIs** (e.g. `Uri.file('/abs/path/setup.dart')`):
///   Interpreted as absolute file paths on the filesystem.
///
/// If execution fails, throws an exception containing the string representation
/// and stack trace of the error thrown by the setup script.
Future<Object?> globalSetup(Uri uri) async {
  final url = uri.toString();

  var channel = Zone.current[#test.runner.test_channel] as MultiChannel?;
  if (channel == null) {
    var fallback = globalSetupStandaloneFallback;
    if (fallback != null) {
      return (await fallback(uri));
    }
    throw UnsupportedError("Can't connect to the test runner.");
  }

  var virtualChannel = channel.virtualChannel();
  channel.sink.add({
    'type': 'global-setup',
    'url': url,
    'channel': virtualChannel.id,
  });

  final completer = Completer<Object?>();
  virtualChannel.stream.listen(
    (message) {
      if (message is Map) {
        if (message['type'] == 'data') {
          completer.complete(message['data']);
        } else if (message['type'] == 'error') {
          final error = RemoteException.deserialize(message['error'] as Map);
          completer.completeError(error.error, error.stackTrace);
        }
      }
    },
    onError: completer.completeError,
    onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Global setup channel closed before producing a result.'),
        );
      }
    },
  );

  return completer.future;
}

/// Registers a callback to be run during global teardown when the test runner
/// closes.
///
/// This must be called from within a global setup script invoked via [globalSetup].
///
/// It is an error if this is called outside of a global setup script.
void addGlobalTearDown(FutureOr<void> Function() callback) {
  final list =
      Zone.current[#test.global_teardowns] as List<FutureOr<void> Function()>?;
  if (list == null) {
    throw UnsupportedError(
      'addGlobalTearDown() can only be called from within a global setup script.',
    );
  }
  list.add(callback);
}
