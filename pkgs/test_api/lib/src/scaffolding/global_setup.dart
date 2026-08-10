// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import '../backend/remote_exception.dart';

/// Runs a global setup Dart script at [uri] on the host test runner if it
/// has not yet run, and returns its result.
///
/// If multiple test suites or tests invoke [globalSetup] with the same [uri],
/// the script runs only once and all callers receive the same cached result.
///
/// The Dart file at [uri] must define a top-level `main()` function that
/// returns a JSON-encodable value (or `Future` of one).
///
/// If [uri] is a relative path or [Uri], it is interpreted relative to the test
/// file's directory. If it is root-relative (starts with `/`), it is interpreted
/// relative to the package root.
///
/// It is an error if [uri] is not a [String] or [Uri], or if [globalSetup] is
/// called outside of `dart test`.
///
/// Throws whatever exception was thrown by the setup script if execution fails.
Future<T> globalSetup<T>(Object uri) async {
  String url;
  if (uri is String) {
    url = uri;
  } else if (uri is Uri) {
    url = uri.toString();
  } else {
    throw ArgumentError.value(uri, 'uri', 'must be a Uri or a String.');
  }

  var channel = Zone.current[#test.runner.test_channel] as MultiChannel?;
  if (channel == null) {
    throw UnsupportedError(
      "Can't connect to the test runner.\n"
      'globalSetup() is currently only supported within "dart test".',
    );
  }

  var virtualChannel = channel.virtualChannel();
  channel.sink.add({
    'type': 'global-setup',
    'url': url,
    'channel': virtualChannel.id,
  });

  final completer = Completer<T>();
  virtualChannel.stream.listen(
    (message) {
      if (message is Map) {
        if (message['type'] == 'data') {
          completer.complete(message['data'] as T);
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
