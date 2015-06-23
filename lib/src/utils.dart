// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.utils;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:stack_trace/stack_trace.dart';

import 'backend/operating_system.dart';
import 'util/path_handler.dart';

/// A typedef for a possibly-asynchronous function.
///
/// The return type should only ever by [Future] or void.
typedef AsyncFunction();

/// A typedef for a zero-argument callback function.
typedef void Callback();

/// A converter that decodes bytes using UTF-8 and splits them on newlines.
final lineSplitter = UTF8.decoder.fuse(const LineSplitter());

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

/// A pair of values.
class Pair<E, F> {
  E first;
  F last;

  Pair(this.first, this.last);

  String toString() => '($first, $last)';

  bool operator==(other) {
    if (other is! Pair) return false;
    return other.first == first && other.last == last;
  }

  int get hashCode => first.hashCode ^ last.hashCode;
}

/// Get a string description of an exception.
///
/// Many exceptions include the exception class name at the beginning of their
/// [toString], so we remove that if it exists.
String getErrorMessage(error) =>
  error.toString().replaceFirst(_exceptionPrefix, '');

/// Indent each line in [str] by two spaces.
String indent(String str) =>
    str.replaceAll(new RegExp("^", multiLine: true), "  ");

/// A regular expression matching terminal color codes.
final _colorCode = new RegExp('\u001b\\[[0-9;]+m');

/// Returns [str] without any color codes.
String withoutColors(String str) => str.replaceAll(_colorCode, '');

/// A regular expression matching the path to a temporary file used to start an
/// isolate.
///
/// These paths aren't relevant and are removed from stack traces.
final _isolatePath =
    new RegExp(r"/test_[A-Za-z0-9]{6}/runInIsolate\.dart$");

/// Returns [stackTrace] converted to a [Chain] with all irrelevant frames
/// folded together.
///
/// If [verbose] is `true`, returns the chain for [stackTrace] unmodified.
Chain terseChain(StackTrace stackTrace, {bool verbose: false}) {
  if (verbose) return new Chain.forTrace(stackTrace);
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

/// Returns a new map with all values in both [map1] and [map2].
///
/// If there are conflicting keys, [map2]'s value wins.
Map mergeMaps(Map map1, Map map2) {
  var result = {};
  map1.forEach((key, value) {
    result[key] = value;
  });
  map2.forEach((key, value) {
    result[key] = value;
  });
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

/// Like [runZoned], but [zoneValues] are set for the callbacks in
/// [zoneSpecification] and [onError].
runZonedWithValues(body(), {Map zoneValues,
    ZoneSpecification zoneSpecification, Function onError}) {
  return runZoned(() {
    return runZoned(body,
        zoneSpecification: zoneSpecification, onError: onError);
  }, zoneValues: zoneValues);
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

/// Returns a human-friendly representation of [duration].
String niceDuration(Duration duration) {
  var minutes = duration.inMinutes;
  var seconds = duration.inSeconds % 59;
  var decaseconds = (duration.inMilliseconds % 1000) ~/ 100;

  var buffer = new StringBuffer();
  if (minutes != 0) buffer.write("$minutes minutes");

  if (minutes == 0 || seconds != 0) {
    if (minutes != 0) buffer.write(", ");
    buffer.write(seconds);
    if (decaseconds != 0) buffer.write(".$decaseconds");
    buffer.write(" seconds");
  }

  return buffer.toString();
}

/// Merges [streams] into a single stream that emits events from all sources.
Stream mergeStreams(Iterable<Stream> streamIter) {
  var streams = streamIter.toList();

  var subscriptions = new Set();
  var controller;
  controller = new StreamController(sync: true, onListen: () {
    for (var stream in streams) {
      var subscription;
      subscription = stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
        subscriptions.remove(subscription);
        if (subscriptions.isEmpty) controller.close();
      });
      subscriptions.add(subscription);
    }
  }, onPause: () {
    for (var subscription in subscriptions) {
      subscription.pause();
    }
  }, onResume: () {
    for (var subscription in subscriptions) {
      subscription.resume();
    }
  }, onCancel: () {
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
  });

  return controller.stream;
}

/// Returns the first value [stream] emits, or `null` if [stream] closes before
/// emitting a value.
Future maybeFirst(Stream stream) {
  var completer = new Completer();

  var subscription;
  subscription = stream.listen((data) {
    completer.complete(data);
    subscription.cancel();
  }, onError: (error, stackTrace) {
    completer.completeError(error, stackTrace);
    subscription.cancel();
  }, onDone: () {
    completer.complete();
  });

  return completer.future;
}

/// Returns a stream that emits [error] and [stackTrace], then closes.
///
/// This is useful for adding errors to streams defined via `async*`.
Stream errorStream(error, StackTrace stackTrace) {
  var controller = new StreamController();
  controller.addError(error, stackTrace);
  controller.close();
  return controller.stream;
}

/// Runs [fn] and discards its return value.
///
/// This is useful for making a block of code async without forcing the
/// containing method to return a future.
void invoke(fn()) {
  fn();
}

/// Returns a random base64 string containing [bytes] bytes of data.
///
/// [seed] is passed to [math.Random]; [urlSafe] and [addLineSeparator] are
/// passed to [CryptoUtils.bytesToBase64].
String randomBase64(int bytes, {int seed, bool urlSafe: false,
    bool addLineSeparator: false}) {
  var random = new math.Random(seed);
  var data = [];
  for (var i = 0; i < bytes; i++) {
    data.add(random.nextInt(256));
  }
  return CryptoUtils.bytesToBase64(data,
      urlSafe: urlSafe, addLineSeparator: addLineSeparator);
}

// TODO(nweiz): Remove this and [shelfChange] once Shelf 0.6.0 has been out for
// six months or so.
/// Returns `request.url` in a cross-version way.
///
/// This follows the semantics of Shelf 0.6.x, even when using Shelf 0.5.x: the
/// returned URL never starts with "/".
Uri shelfUrl(shelf.Request request) {
  var url = request.url;
  if (!url.path.startsWith("/")) return url;
  return url.replace(path: url.path.replaceFirst("/", ""));
}

/// Like [shelf.Request.change], but cross-version.
///
/// This follows the semantics of Shelf 0.6.x, even when using Shelf 0.5.x.
shelf.Request shelfChange(shelf.Request typedRequest, {String path}) {
  // Explicitly make the request dynamic since we're calling methods here that
  // aren't defined in all support Shelf versions, and we don't want the
  // analyzer to complain.
  var request = typedRequest as dynamic;

  try {
    return request.change(path: path);
  } on NoSuchMethodError catch (_) {
    var newScriptName = p.url.join(request.scriptName, path);
    if (request.scriptName.isEmpty) newScriptName = "/" + newScriptName;

    var newUrlPath = p.url.relative(request.url.path.replaceFirst("/", ""),
        from: path);
    newUrlPath = newUrlPath == "." ? "" : "/" + newUrlPath;

    return request.change(
        scriptName: newScriptName, url: request.url.replace(path: newUrlPath));
  }
}

/// Returns middleware that nests all requests beneath the URL prefix [beneath].
shelf.Middleware nestingMiddleware(String beneath) {
  return (handler) {
    var pathHandler = new PathHandler()..add(beneath, handler);
    return pathHandler.handler;
  };
}
