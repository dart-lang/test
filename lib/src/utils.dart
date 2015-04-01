// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.utils;

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import 'backend/operating_system.dart';

/// A typedef for a possibly-asynchronous function.
///
/// The return type should only ever by [Future] or void.
typedef AsyncFunction();

/// A regular expression to match the exception prefix that some exceptions'
/// [Object.toString] values contain.
final _exceptionPrefix = new RegExp(r'^([A-Z][a-zA-Z]*)?(Exception|Error): ');

/// Directories that are specific to OS X.
///
/// This is used to try to distinguish OS X and Linux in [currentOSGuess].
final _macOSDirectories = new Set<String>.from([
  "/Applications",
  "/Library",
  "/Network",
  "/System",
  "/Users"
]);

/// Returns the best guess for the current operating system without using
/// `dart:io`.
///
/// This is useful for running test files directly and skipping tests as
/// appropriate. The only OS-specific information we have is the current path,
/// which we try to use to figure out the OS.
final OperatingSystem currentOSGuess = (() {
  if (p.style == p.Style.url) return OperatingSystem.none;
  if (p.style == p.Style.windows) return OperatingSystem.windows;
  if (_macOSDirectories.any(p.current.startsWith)) return OperatingSystem.macOS;
  return OperatingSystem.linux;
})();

/// Get a string description of an exception.
///
/// Many exceptions include the exception class name at the beginning of their
/// [toString], so we remove that if it exists.
String getErrorMessage(error) =>
  error.toString().replaceFirst(_exceptionPrefix, '');

/// Indent each line in [str] by two spaces.
String indent(String str) =>
    str.replaceAll(new RegExp("^", multiLine: true), "  ");

/// A regular expression matching the path to a temporary file used to start an
/// isolate.
///
/// These paths aren't relevant and are removed from stack traces.
final _isolatePath =
    new RegExp(r"/test_[A-Za-z0-9]{6}/runInIsolate\.dart$");

/// Returns [stackTrace] converted to a [Chain] with all irrelevant frames
/// folded together.
Chain terseChain(StackTrace stackTrace) {
  return new Chain.forTrace(stackTrace).foldFrames((frame) {
    if (frame.package == 'test') return true;

    // Filter out frames from our isolate bootstrap as well.
    if (frame.uri.scheme != 'file') return false;
    return frame.uri.path.contains(_isolatePath);
  }, terse: true);
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

/// Returns a sink that maps events sent to [original] using [fn].
StreamSink mapSink(StreamSink original, fn(event)) {
  var controller = new StreamController(sync: true);
  controller.stream.listen(
      (event) => original.add(fn(event)),
      onError: (error, stackTrace) => original.addError(error, stackTrace),
      onDone: () => original.close());
  return controller.sink;
}

/// Truncates [text] to fit within [maxLength].
///
/// This will try to truncate along word boundaries and preserve words both at
/// the beginning and the end of [text].
String truncate(String text, int maxLength) {
  // Return the full message if it fits.
  if (text.length <= maxLength) return text;

  // If we can fit the first and last three words, do so.
  var words = text.split(' ');
  if (words.length > 1) {
    var i = words.length;
    var length = words.first.length + 4;
    do {
      i--;
      length += 1 + words[i].length;
    } while (length <= maxLength && i > 0);
    if (length > maxLength || i == 0) i++;
    if (i < words.length - 4) {
      // Require at least 3 words at the end.
      var buffer = new StringBuffer();
      buffer.write(words.first);
      buffer.write(' ...');
      for ( ; i < words.length; i++) {
        buffer.write(' ');
        buffer.write(words[i]);
      }
      return buffer.toString();
    }
  }

  // Otherwise truncate to return the trailing text, but attempt to start at
  // the beginning of a word.
  var result = text.substring(text.length - maxLength + 4);
  var firstSpace = result.indexOf(' ');
  if (firstSpace > 0) {
    result = result.substring(firstSpace);
  }
  return '...$result';
}
