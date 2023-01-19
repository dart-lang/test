// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

/// Returns a pretty-printed representation of [object].
///
/// When possible, lines will be kept under [_maxLineLength]. This isn't
/// guaranteed, since individual objects may have string representations that
/// are too long, but most lines will be less than [_maxLineLength] long.
///
/// [Iterable]s and [Map]s will only print their first [_maxItems] elements or
/// key/value pairs, respectively.
Iterable<String> literal(Object? object) => _prettyPrint(object, 0, {}, true);

const _maxLineLength = 80;
const _maxItems = 25;

Iterable<String> _prettyPrint(
    Object? object, int indentSize, Set<Object?> seen, bool isTopLevel) {
  if (seen.contains(object)) return ['(recursive)'];
  seen = seen.union({object});
  Iterable<String> prettyPrintNested(Object? child) =>
      _prettyPrint(child, indentSize + 2, seen, false);

  if (object is Iterable) {
    String open, close;
    if (object is List) {
      open = '[';
      close = ']';
    } else if (object is Set) {
      open = '{';
      close = '}';
    } else {
      open = '(';
      close = ')';
    }
    final elements = object.map(prettyPrintNested).toList();
    return _prettyPrintCollection(
        open, close, elements, _maxLineLength - indentSize);
  } else if (object is Map) {
    final entries = object.entries.map((entry) {
      final key = prettyPrintNested(entry.key);
      final value = prettyPrintNested(entry.value);
      return [
        ...key.take(key.length - 1),
        '${key.last}: ${value.first}',
        ...value.skip(1)
      ];
    }).toList();
    return _prettyPrintCollection(
        '{', '}', entries, _maxLineLength - indentSize);
  } else if (object is String) {
    if (object.isEmpty) return ["''"];
    final escaped = const LineSplitter()
        .convert(object)
        .map(escape)
        .map((line) => line.replaceAll("'", r"\'"))
        .toList();
    return prefixFirst("'", postfixLast("'", escaped));
  } else {
    final value = const LineSplitter().convert(object.toString());
    return isTopLevel ? prefixFirst('<', postfixLast('>', value)) : value;
  }
}

Iterable<String> _prettyPrintCollection(
    String open, String close, List<Iterable<String>> elements, int maxLength) {
  if (elements.length > _maxItems) {
    elements.replaceRange(_maxItems - 1, elements.length, [
      ['...']
    ]);
  }
  if (elements.every((e) => e.length == 1)) {
    final singleLine = '$open${elements.map((e) => e.single).join(', ')}$close';
    if (singleLine.length <= maxLength) {
      return [singleLine];
    }
  }
  if (elements.length == 1) {
    return prefixFirst(open, postfixLast(close, elements.single));
  }
  return [
    ...prefixFirst(open, postfixLast(',', elements.first)),
    for (var element in elements.skip(1).take(elements.length - 2))
      ...postfixLast(',', element),
    ...postfixLast(close, elements.last),
  ];
}

Iterable<String> indent(Iterable<String> lines, [int depth = 1]) {
  final indent = '  ' * depth;
  return lines.map((line) => '$indent$line');
}

/// Prepends [prefix] to the first line of [lines].
///
/// If [lines] is empty, the result will be as well. The prefix will not be
/// returned for an empty input.
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

/// Append [postfix] to the last line of [lines].
///
/// If [lines] is empty, the result will be as well. The postfix will not be
/// returned for an empty input.
Iterable<String> postfixLast(String postfix, Iterable<String> lines) sync* {
  var iterator = lines.iterator;
  var hasNext = iterator.moveNext();
  while (hasNext) {
    final line = iterator.current;
    hasNext = iterator.moveNext();
    yield hasNext ? line : '$line$postfix';
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
