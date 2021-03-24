// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:matcher/matcher.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

/// Returns [name] if [number] is 1, or the plural of [name] otherwise.
///
/// By default, this just adds "s" to the end of [name] to get the plural. If
/// [plural] is passed, that's used instead.
String pluralize(String name, int number, {String? plural}) {
  if (number == 1) return name;
  if (plural != null) return plural;
  return '${name}s';
}

/// Indent each line in [string] by [first.length] spaces.
///
/// [first] is used in place of the first line's indentation.
String indent(String text, {required String first}) {
  final prefix = ' ' * first.length;
  var lines = text.split('\n');
  if (lines.length == 1) return '$first$text';

  var buffer = StringBuffer('$first${lines.first}\n');

  // Write out all but the first and last lines with [prefix].
  for (var line in lines.skip(1).take(lines.length - 2)) {
    buffer.writeln('$prefix$line');
  }
  buffer.write('$prefix${lines.last}');
  return buffer.toString();
}

/// Indents [text], and adds a bullet at the beginning.
String addBullet(String text) => indent(text, first: '${glyph.bullet} ');

/// Converts [strings] to a bulleted list.
String bullet(Iterable<String> strings) => strings.map(addBullet).join('\n');

/// Returns a pretty-printed representation of [value].
///
/// The matcher package doesn't expose its pretty-print function directly, but
/// we can use it through StringDescription.
String prettyPrint(value) =>
    StringDescription().addDescriptionOf(value).toString();

/// Returns a sentence fragment listing the elements of [iter].
///
/// This converts each element of [iter] to a string and separates them with
/// commas and/or [conjunction] where appropriate. The [conjunction] defaults to
/// "and".
String toSentence(Iterable<Object> iter, {String conjunction = 'and'}) {
  if (iter.length == 1) return iter.first.toString();

  var result = iter.take(iter.length - 1).join(', ');
  if (iter.length > 2) result += ',';
  return '$result $conjunction ${iter.last}';
}

/// Returns a human-friendly representation of [duration].
String niceDuration(Duration duration) {
  var minutes = duration.inMinutes;
  var seconds = duration.inSeconds % 60;
  var decaseconds = (duration.inMilliseconds % 1000) ~/ 100;

  var buffer = StringBuffer();
  if (minutes != 0) buffer.write('$minutes minutes');

  if (minutes == 0 || seconds != 0) {
    if (minutes != 0) buffer.write(', ');
    buffer.write(seconds);
    if (decaseconds != 0) buffer.write('.$decaseconds');
    buffer.write(' seconds');
  }

  return buffer.toString();
}
