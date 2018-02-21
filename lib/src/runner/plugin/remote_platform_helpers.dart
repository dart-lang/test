// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import '../../backend/stack_trace_formatter.dart';
import '../../util/stack_trace_mapper.dart';
import '../remote_listener.dart';
import '../suite_channel_manager.dart';

/// Returns a channel that will emit a serialized representation of the tests
/// defined in [getMain].
///
/// This channel is used to control the tests. Platform plugins should forward
/// it to the return value of [PlatformPlugin.loadChannel]. It's guaranteed to
/// communicate using only JSON-serializable values.
///
/// Any errors thrown within [getMain], synchronously or not, will be forwarded
/// to the load test for this suite. Prints will similarly be forwarded to that
/// test's print stream.
///
/// If [hidePrints] is `true` (the default), calls to `print()` within this
/// suite will not be forwarded to the parent zone's print handler. However, the
/// caller may want them to be forwarded in (for example) a browser context
/// where they'll be visible in the development console.
///
/// If [beforeLoad] is passed, it's called before the tests have been declared
/// for this worker.
StreamChannel serializeSuite(Function getMain(),
        {bool hidePrints: true, Future beforeLoad()}) =>
    RemoteListener.start(getMain,
        hidePrints: hidePrints, beforeLoad: beforeLoad);

/// Returns a channel that communicates with a plugin in the test runner.
///
/// This connects to a channel created by code in the test runner calling
/// `RunnerSuite.channel()` with the same name. It can be used used to send and
/// receive any JSON-serializable object.
///
/// Throws a [StateError] if [name] has already been used for a channel, or if
/// this is called outside a worker context (such as within a running test or
/// `serializeSuite()`'s `onLoad()` function).
StreamChannel suiteChannel(String name) {
  var manager = SuiteChannelManager.current;
  if (manager == null) {
    throw new StateError(
        'suiteChannel() may only be called within a test worker.');
  }

  return manager.connectOut(name);
}

/// Sets the stack trace mapper for the current test suite.
///
/// This is used to convert JavaScript stack traces into their Dart equivalents
/// using source maps. It should be set before any tests run, usually in the
/// `onLoad()` callback to [serializeSuite].
void setStackTraceMapper(StackTraceMapper mapper) {
  var formatter = StackTraceFormatter.current;
  if (formatter == null) {
    throw new StateError(
        'setStackTraceMapper() may only be called within a test worker.');
  }

  formatter.configure(mapper: mapper);
}
