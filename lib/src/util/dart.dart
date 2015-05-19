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
import 'remote_exception.dart';

/// Runs [code] in an isolate.
///
/// [code] should be the contents of a Dart entrypoint. It may contain imports;
/// they will be resolved in the same context as the host isolate. [message] is
/// passed to the [main] method of the code being run; the caller is responsible
/// for using this to establish communication with the isolate.
///
/// [packageRoot] controls the package root of the isolate. It may be either a
/// [String] or a [Uri].
Future<IsolateWrapper> runInIsolate(String code, message, {packageRoot}) async {
  // TODO(nweiz): load code from a local server rather than from a file.
  var dir = createTempDir();
  var dartPath = p.join(dir, 'runInIsolate.dart');
  new File(dartPath).writeAsStringSync(code);
  var port = new ReceivePort();

  try {
    var isolate = await Isolate.spawn(_isolateBuffer, {
      'replyTo': port.sendPort,
      'uri': p.toUri(dartPath).toString(),
      'packageRoot': packageRoot == null ? null : packageRoot.toString(),
      'message': message
    });

    var response = await port.first;
    if (response['type'] != 'error') {
      return new IsolateWrapper(isolate,
          () => new Directory(dir).deleteSync(recursive: true));
    }

    if (supportsIsolateKill) isolate.kill();
    var asyncError = RemoteException.deserialize(response['error']);
    await new Future.error(asyncError.error, asyncError.stackTrace);
    throw 'unreachable';
  } catch (error) {
    new Directory(dir).deleteSync(recursive: true);
    rethrow;
  }
}

// TODO(nweiz): remove this when issue 12617 is fixed.
/// A function used as a buffer between the host isolate and [spawnUri].
///
/// [spawnUri] synchronously loads the file and its imports, which can deadlock
/// the host isolate if there's an HTTP import pointing at a server in the host.
/// Adding an additional isolate in the middle works around this.
Future _isolateBuffer(message) async {
  var replyTo = message['replyTo'];
  var packageRoot = message['packageRoot'];
  if (packageRoot != null) packageRoot = Uri.parse(packageRoot);

  try {
    await Isolate.spawnUri(Uri.parse(message['uri']), [], message['message'],
        packageRoot: packageRoot);
    replyTo.send({'type': 'success'});
  } catch (error, stackTrace) {
    replyTo.send({
      'type': 'error',
      'error': RemoteException.serialize(error, stackTrace)
    });
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
