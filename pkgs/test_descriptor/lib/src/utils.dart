// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';

import 'descriptor.dart';
import 'sandbox.dart';

/// A UTF-8 codec that allows malformed byte sequences.
final utf8 = const Utf8Codec(allowMalformed: true);

/// Prepends a vertical bar to [text].
String addBar(String text) => prefixLines(text, '${glyph.verticalLine} ',
    first: '${glyph.downEnd} ', last: '${glyph.upEnd} ', single: '| ');

/// Indents [text], and adds a bullet at the beginning.
String addBullet(String text) =>
    prefixLines(text, '  ', first: '${glyph.bullet} ');

/// Converts [strings] to a bulleted list.
String bullet(Iterable<String> strings) => strings.map(addBullet).join('\n');

/// Returns a human-readable description of a directory with the given [name]
/// and [contents].
String describeDirectory(String name, List<Descriptor> contents) {
  if (contents.isEmpty) return name;

  var buffer = StringBuffer();
  buffer.writeln(name);
  for (var entry in contents.take(contents.length - 1)) {
    var entryString = prefixLines(entry.describe(), '${glyph.verticalLine}   ',
        first: '${glyph.teeRight}${glyph.horizontalLine}'
            '${glyph.horizontalLine} ');
    buffer.writeln(entryString);
  }

  var lastEntryString = prefixLines(contents.last.describe(), '    ',
      first: '${glyph.bottomLeftCorner}${glyph.horizontalLine}'
          '${glyph.horizontalLine} ');
  buffer.write(lastEntryString);
  return buffer.toString();
}

/// Prepends each line in [text] with [prefix].
///
/// If [first] or [last] is passed, the first and last lines, respectively, are
/// prefixed with those instead. If [single] is passed, it's used if there's
/// only a single line; otherwise, [first], [last], or [prefix] is used, in that
/// order of precedence.
String prefixLines(String text, String prefix,
    {String first, String last, String single}) {
  first ??= prefix;
  last ??= prefix;
  single ??= first ?? last ?? prefix;

  var lines = text.split('\n');
  if (lines.length == 1) return '$single$text';

  var buffer = StringBuffer('$first${lines.first}\n');
  for (var line in lines.skip(1).take(lines.length - 2)) {
    buffer.writeln('$prefix$line');
  }
  buffer.write('$last${lines.last}');
  return buffer.toString();
}

/// Returns a representation of [path] that's easy for humans to read.
///
/// This may not be a valid path relative to [p.current].
String prettyPath(String path) {
  if (sandboxExists && p.isWithin(sandbox, path)) {
    return p.relative(path, from: sandbox);
  } else if (p.isWithin(p.current, path)) {
    return p.relative(path);
  } else {
    return path;
  }
}

/// Returns whether [pattern] matches all of [string].
bool matchesAll(Pattern pattern, String string) =>
    pattern.matchAsPrefix(string)?.end == string.length;

/// Like [Future.wait] with `eagerError: true`, but reports errors after the
/// first using [registerException] rather than silently ignoring them.
Future<List<T>> waitAndReportErrors<T>(Iterable<Future<T>> futures) {
  var errored = false;
  return Future.wait(futures.map((future) {
    // Avoid async/await so that we synchronously add error handlers for the
    // futures to keep them from top-leveling.
    return future.catchError((error, StackTrace stackTrace) {
      if (!errored) {
        errored = true;
        throw error;
      } else {
        registerException(error, stackTrace);
      }
    });
  }));
}
