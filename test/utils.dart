// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.test.utils;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import 'package:unittest/src/live_test.dart';
import 'package:unittest/src/remote_exception.dart';
import 'package:unittest/src/state.dart';
import 'package:unittest/unittest.dart';

// The last state change detected via [expectStates].
State lastState;

final String packageDir = _computePackageDir();

String _computePackageDir() {
  var trace = new Trace.current();
  return p.dirname(p.dirname(p.fromUri(trace.frames.first.uri)));
}

/// Asserts that exactly [states] will be emitted via [liveTest.onStateChange].
///
/// The most recent emitted state is stored in [_lastState].
void expectStates(LiveTest liveTest, Iterable<State> statesIter) {
  var states = new Queue.from(statesIter);
  liveTest.onStateChange.listen(expectAsync((state) {
    lastState = state;
    expect(state, equals(states.removeFirst()));
  }, count: states.length, max: states.length));
}

/// Asserts that errors will be emitted via [liveTest.onError] that match
/// [validators], in order.
void expectErrors(LiveTest liveTest, Iterable<Function> validatorsIter) {
  var validators = new Queue.from(validatorsIter);
  liveTest.onError.listen(expectAsync((error) {
    validators.removeFirst()(error.error);
  }, count: validators.length, max: validators.length));
}

/// Asserts that [liveTest] will have a single failure with message `"oh no"`.
void expectSingleFailure(LiveTest liveTest) {
  expectStates(liveTest, [
    const State(Status.running, Result.success),
    const State(Status.complete, Result.failure)
  ]);

  expectErrors(liveTest, [(error) {
    expect(lastState.status, equals(Status.complete));
    expect(error, isTestFailure("oh no"));
  }]);
}

/// Asserts that [liveTest] will have a single error, the string `"oh no"`.
void expectSingleError(LiveTest liveTest) {
  expectStates(liveTest, [
    const State(Status.running, Result.success),
    const State(Status.complete, Result.error)
  ]);

  expectErrors(liveTest, [(error) {
    expect(lastState.status, equals(Status.complete));
    expect(error, equals("oh no"));
  }]);
}

/// Returns a matcher that matches a [TestFailure] with the given [message].
Matcher isTestFailure(String message) => predicate(
    (error) => error is TestFailure && error.message == message,
    'is a TestFailure with message "$message"');

/// Returns a matcher that matches a [RemoteException] with the given [message].
Matcher isRemoteException(String message) => predicate(
    (error) => error is RemoteException && error.message == message,
    'is a RemoteException with message "$message"');

/// Returns a matcher that matches a [FileSystemException] with the given
/// [message].
Matcher isFileSystemException(String message) => predicate(
    (error) => error is FileSystemException && error.message == message,
    'is a FileSystemException with message "$message"');

/// Returns a [Future] that completes after pumping the event queue [times]
/// times.
///
/// By default, this should pump the event queue enough times to allow any code
/// to run, as long as it's not waiting on some external event.
Future pumpEventQueue([int times=20]) {
  if (times == 0) return new Future.value();
  // Use [new Future] future to allow microtask events to finish. The [new
  // Future.value] constructor uses scheduleMicrotask itself and would therefore
  // not wait for microtask callbacks that are scheduled after invoking this
  // method.
  return new Future(() => pumpEventQueue(times - 1));
}
