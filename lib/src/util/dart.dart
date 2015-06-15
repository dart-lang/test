// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.dart;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'string_literal_iterator.dart';
import 'io.dart';
import 'isolate_wrapper.dart';

/// Runs [code] in an isolate.
///
/// [code] should be the contents of a Dart entrypoint. It may contain imports;
/// they will be resolved in the same context as the host isolate. [message] is
/// passed to the [main] method of the code being run; the caller is responsible
/// for using this to establish communication with the isolate.
///
/// [packageRoot] controls the package root of the isolate. It may be either a
/// [String] or a [Uri].
Future<IsolateWrapper> runInIsolate(String code, message, {packageRoot,
    bool checked}) async {
  // TODO(nweiz): load code from a local server rather than from a file.
  var dir = createTempDir();
  var dartPath = p.join(dir, 'runInIsolate.dart');
  new File(dartPath).writeAsStringSync(code);

  return await spawnUri(
      p.toUri(dartPath), message,
      packageRoot: packageRoot,
      checked: checked,
      onExit: () => new Directory(dir).deleteSync(recursive: true));
}

/// Like [Isolate.spawnUri], except that [uri] and [packageRoot] may be strings,
/// [checked] mode is silently ignored on older Dart versions, and [onExit] is
/// run after the isolate is killed.
///
/// If the isolate fails to load, [onExit] will also be run.
Future<IsolateWrapper> spawnUri(uri, message, {packageRoot, bool checked,
    void onExit()}) async {
  if (uri is String) uri = Uri.parse(uri);
  if (packageRoot is String) packageRoot = Uri.parse(packageRoot);
  if (onExit == null) onExit = () {};

  try {
    var isolate = supportsIsolateCheckedMode
        ? await Isolate.spawnUri(
            uri, [], message, checked: checked, packageRoot: packageRoot)
        : await Isolate.spawnUri(
            uri, [], message, packageRoot: packageRoot);
    return new IsolateWrapper(isolate, onExit);
  } catch (error) {
    onExit();
    rethrow;
  }
}

// TODO(nweiz): Move this into the analyzer once it starts using SourceSpan
// (issue 22977).
/// Takes a span whose source is the value of a string that has been parsed from
/// a Dart file and returns the corresponding span from within that Dart file.
///
/// For example, suppose a Dart file contains `@Eval("1 + a")`. The
/// [StringLiteral] `"1 + a"` is extracted; this is [context]. Its contents are
/// then parsed, producing an error pointing to [span]:
///
///     line 1, column 5:
///     1 + a
///         ^
///
/// This span isn't very useful, since it only shows the location within the
/// [StringLiteral]'s value. So it's passed to [contextualizeSpan] along with
/// [context] and [file] (which contains the source of the entire Dart file),
/// which then returns:
///
///     line 4, column 12 of file.dart:
///     @Eval("1 + a")
///                ^
///
/// This properly handles multiline literals, adjacent literals, and literals
/// containing escape sequences. It does not support interpolated literals.
///
/// This will return `null` if [context] contains an invalid string or does not
/// contain [span].
SourceSpan contextualizeSpan(SourceSpan span, StringLiteral context,
    SourceFile file) {
  var contextRunes = new StringLiteralIterator(context)..moveNext();

  for (var i = 0; i < span.start.offset; i++) {
    if (!contextRunes.moveNext()) return null;
  }

  var start = contextRunes.offset;
  for (var spanRune in span.text.runes) {
    if (spanRune != contextRunes.current) return null;
    contextRunes.moveNext();
  }

  return file.span(start, contextRunes.offset);
}
