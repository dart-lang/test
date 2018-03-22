// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stack_trace/stack_trace.dart';

import '../backend/stack_trace_formatter.dart';

/// The default formatter to use for formatting stack traces.
///
/// This is used in situations where the zone-scoped formatter is unavailable,
/// such as when running via `dart path/to/test.dart'.
final _defaultFormatter = new StackTraceFormatter();

/// Converts [stackTrace] to a [Chain] according to the current test's
/// configuration.
///
/// If [verbose] is `true`, this doesn't fold out irrelevant stack frames. It
/// defaults to the current test's `verbose_trace` configuration.
Chain formatStackTrace(StackTrace stackTrace, {bool verbose}) =>
    (StackTraceFormatter.current ?? _defaultFormatter)
        .formatStackTrace(stackTrace, verbose: verbose);
