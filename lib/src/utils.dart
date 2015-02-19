// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.utils;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

/// A typedef for a possibly-asynchronous function.
///
/// The return type should only ever by [Future] or void.
typedef AsyncFunction();

/// A regular expression to match the exception prefix that some exceptions'
/// [Object.toString] values contain.
final _exceptionPrefix = new RegExp(r'^([A-Z][a-zA-Z]*)?(Exception|Error): ');

/// Get a string description of an exception.
///
/// Many exceptions include the exception class name at the beginning of their
/// [toString], so we remove that if it exists.
String getErrorMessage(error) =>
  error.toString().replaceFirst(_exceptionPrefix, '');

/// Indent each line in [str] by two spaces.
String indent(String str) =>
    str.replaceAll(new RegExp("^", multiLine: true), "  ");

/// A pair of values.
class Pair<E, F> {
  final E first;
  final F last;

  Pair(this.first, this.last);

  String toString() => '($first, $last)';

  bool operator ==(other) {
    if (other is! Pair) return false;
    return other.first == first && other.last == last;
  }

  int get hashCode => first.hashCode ^ last.hashCode;
}

/// A regular expression matching the path to a temporary file used to start an
/// isolate.
///
/// These paths aren't relevant and are removed from stack traces.
final _isolatePath =
    new RegExp(r"/unittest_[A-Za-z0-9]{6}/runInIsolate\.dart$");

/// Returns [stackTrace] converted to a [Chain] with all irrelevant frames
/// folded together.
Chain terseChain(StackTrace stackTrace) {
  return new Chain.forTrace(stackTrace).foldFrames((frame) {
    if (frame.package == 'unittest') return true;

    // Filter out frames from our isolate bootstrap as well.
    if (frame.uri.scheme != 'file') return false;
    return frame.uri.path.contains(_isolatePath);
  }, terse: true);
}

/// Returns a Trace object from a StackTrace object or a String, or the
/// unchanged input if formatStacks is false;
Trace getTrace(stack, bool formatStacks, bool filterStacks) {
  Trace trace;
  if (stack == null || !formatStacks) return null;
  if (stack is String) {
    trace = new Trace.parse(stack);
  } else if (stack is StackTrace) {
    trace = new Trace.from(stack);
  } else {
    throw new Exception('Invalid stack type ${stack.runtimeType} for $stack.');
  }

  if (!filterStacks) return trace;

  // Format the stack trace by removing everything above TestCase._runTest,
  // which is usually going to be irrelevant. Also fold together unittest and
  // core library calls so only the function the user called is visible.
  return new Trace(trace.frames.takeWhile((frame) {
    return frame.package != 'unittest' || frame.member != 'TestCase._runTest';
  })).terse.foldFrames((frame) => frame.package == 'unittest' || frame.isCore);
}

/// Flattens nested [Iterable]s inside an [Iterable] into a single [List]
/// containing only non-[Iterable] elements.
List flatten(Iterable nested) {
  var result = [];
  helper(iter) {
    for (var element in iter) {
      if (element is Iterable) {
        helper(element);
      } else {
        result.add(element);
      }
    }
  }
  helper(nested);
  return result;
}
