// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

String literal(Object? o) {
  if (o == null || o is num || o is bool) return '<$o>';
  // TODO Truncate long strings?
  // TODO: handle strings with embedded `'`
  // TODO: special handling of multi-line strings?
  if (o is String) return "'$o'";
  // TODO Truncate long collections?
  return '$o';
}

Iterable<String> indent(Iterable<String> lines, [int depth = 1]) {
  final indent = '  ' * depth;
  return lines.map((line) => '$indent$line');
}

Iterable<String> prefixFirst(String prefix, Iterable<String> lines) sync* {
  var isFirst = true;
  for (var line in lines) {
    if (isFirst) {
      yield '$prefix$line';
      isFirst = false;
    } else {
      yield line;
    }
  }
}

/// Returns [output] with all whitespace characters represented as their escape
/// sequences.
///
/// Backslash characters are escaped as `\\`
String escape(String output) {
  output = output.replaceAll('\\', r'\\');
  return output.replaceAllMapped(_escapeRegExp, (match) {
    var mapped = _escapeMap[match[0]];
    if (mapped != null) return mapped;
    return _hexLiteral(match[0]!);
  });
}

/// A [RegExp] that matches whitespace characters that should be escaped.
final _escapeRegExp = RegExp(
    '[\\x00-\\x07\\x0E-\\x1F${_escapeMap.keys.map(_hexLiteral).join()}]');

/// A [Map] between whitespace characters and their escape sequences.
const _escapeMap = {
  '\n': r'\n',
  '\r': r'\r',
  '\f': r'\f',
  '\b': r'\b',
  '\t': r'\t',
  '\v': r'\v',
  '\x7F': r'\x7F', // delete
};

/// Given single-character string, return the hex-escaped equivalent.
String _hexLiteral(String input) {
  var rune = input.runes.single;
  return r'\x' + rune.toRadixString(16).toUpperCase().padLeft(2, '0');
}
