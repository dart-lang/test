// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../backend/invoker.dart';

/// Returns a [Future] that completes after the [event loop][] has run the given
/// number of [times] (20 by default).
///
/// [event loop]: https://medium.com/dartlang/dart-asynchronous-programming-isolates-and-event-loops-bffc3e296a6a
///
/// Awaiting this approximates waiting until all asynchronous work (other than
/// work that's waiting for external resources) completes.
Future pumpEventQueue({int times = 20}) {
  if (times == 0) return Future.value();
  // Use the event loop to allow the microtask queue to finish.
  return Future(() => pumpEventQueue(times: times - 1));
}

/// Registers an exception that was caught for the current test.
void registerException(Object error,
    [StackTrace stackTrace = StackTrace.empty]) {
  // This will usually forward directly to [Invoker.current.handleError], but
  // going through the zone API allows other zones to consistently see errors.
  Zone.current.handleUncaughtError(error, stackTrace);
}

/// Prints [message] if and when the current test fails.
///
/// This is intended for test infrastructure to provide debugging information
/// without cluttering the output for successful tests. Note that unlike
/// [print], each individual message passed to [printOnFailure] will be
/// separated by a blank line.
void printOnFailure(String message) {
  _currentInvoker.printOnFailure(message);
}

/// Registers a function to be run after the current test.
///
/// This is called within a running test, and adds a tear-down only for the
/// current test. It allows testing libraries to add cleanup logic as soon as
/// there's something to clean up.
///
/// The [callback] is run before any callbacks registered with [tearDown]. Like
/// [tearDown], the most recently registered callback is run first.
///
/// If this is called from within a [setUpAll] or [tearDownAll] callback, it
/// instead runs the function after *all* tests in the current test suite.
void addTearDown(dynamic Function() callback) {
  _currentInvoker.addTearDown(callback);
}

/// Marks the current test as skipped.
///
/// A skipped test may still fail if any exception is thrown, including uncaught
/// asynchronous errors. If the entire test should be skipped `return` from the
/// test body after marking it as skipped.
void markTestSkipped(String message) => _currentInvoker..skip(message);

Invoker get _currentInvoker =>
    Invoker.current ??
    (throw StateError(
        'There is no current invoker. Please make sure that you are making the '
        'call inside a test zone.'));
