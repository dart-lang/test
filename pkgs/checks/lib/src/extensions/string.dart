// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:checks/context.dart';

import 'core.dart';

extension StringChecks on Check<String> {
  /// Expects that the value contains [pattern] according to [String.contains];
  void contains(Pattern pattern) {
    context.expect(() => prefixFirst('contains ', literal(pattern)), (actual) {
      if (actual.contains(pattern)) return null;
      return Rejection(
        actual: literal(actual),
        which: prefixFirst('Does not contain ', literal(pattern)),
      );
    });
  }

  Check<int> get length => has((m) => m.length, 'length');

  void isEmpty() {
    context.expect(() => const ['is empty'], (actual) {
      if (actual.isEmpty) return null;
      return Rejection(actual: literal(actual), which: ['is not empty']);
    });
  }

  void isNotEmpty() {
    context.expect(() => const ['is not empty'], (actual) {
      if (actual.isNotEmpty) return null;
      return Rejection(actual: literal(actual), which: ['is empty']);
    });
  }

  void startsWith(Pattern other) {
    context.expect(
      () => prefixFirst('starts with ', literal(other)),
      (actual) {
        if (actual.startsWith(other)) return null;
        return Rejection(
          actual: literal(actual),
          which: prefixFirst('does not start with ', literal(other)),
        );
      },
    );
  }

  void endsWith(String other) {
    context.expect(
      () => prefixFirst('ends with ', literal(other)),
      (actual) {
        if (actual.endsWith(other)) return null;
        return Rejection(
          actual: literal(actual),
          which: prefixFirst('does not end with ', literal(other)),
        );
      },
    );
  }

  /// Expects that the `String` contains each of the sub strings in expected
  /// in the given order, with any content between them.
  ///
  /// For example, the following will succeed:
  ///
  ///     checkThat('abcdefg').containsInOrder(['a','e']);
  void containsInOrder(Iterable<String> expected) {
    context.expect(() => prefixFirst('contains, in order: ', literal(expected)),
        (actual) {
      var fromIndex = 0;
      for (var s in expected) {
        var index = actual.indexOf(s, fromIndex);
        if (index < 0) {
          return Rejection(actual: literal(actual), which: [
            ...prefixFirst(
                'does not have a match for the substring ', literal(s)),
            if (fromIndex != 0)
              'following the other matches up to character $fromIndex'
          ]);
        }
        fromIndex = index + s.length;
      }
      return null;
    });
  }

  /// Expects that the `String` contains exactly the same code units as
  /// [expected].
  void equals(String expected) {
    context.expect(() => prefixFirst('equals ', literal(expected)),
        (actual) => _findDifference(actual, expected));
  }

  /// Expects that the `String` contains the same characters as [expected] if
  /// both were lower case.
  void equalsIgnoringCase(String expected) {
    context.expect(
        () => prefixFirst('equals ignoring case ', literal(expected)),
        (actual) => _findDifference(
            actual.toLowerCase(), expected.toLowerCase(), actual, expected));
  }

  /// Expects that the `String` contains the same content as [expected],
  /// ignoring differences in whitsepace.
  ///
  /// All runs of whitespace characters are collapsed to a single space, and
  /// leading and traiilng whitespace are removed before comparison.
  ///
  /// For example the following will succeed:
  ///
  ///     checkThat(' hello   world ').equalsIgnoringWhitespace('hello world');
  ///
  /// While the following will fail:
  ///
  ///     checkThat('helloworld').equalsIgnoringWhitespace('hello world');
  ///     checkThat('he llo world').equalsIgnoringWhitespace('hello world');
  void equalsIgnoringWhitespace(String expected) {
    context.expect(
        () => prefixFirst('equals ignoring whitespace ', literal(expected)),
        (actual) {
      final collapsedActual = _collapseWhitespace(actual);
      final collapsedExpected = _collapseWhitespace(expected);
      return _findDifference(collapsedActual, collapsedExpected,
          collapsedActual, collapsedExpected);
    });
  }
}

Rejection? _findDifference(String actual, String expected,
    [String? actualDisplay, String? expectedDisplay]) {
  if (actual == expected) return null;
  final escapedActual = escape(actual);
  final escapedExpected = escape(expected);
  final escapedActualDisplay =
      actualDisplay != null ? escape(actualDisplay) : escapedActual;
  final escapedExpectedDisplay =
      expectedDisplay != null ? escape(expectedDisplay) : escapedExpected;
  final minLength = math.min(escapedActual.length, escapedExpected.length);
  var i = 0;
  for (; i < minLength; i++) {
    if (escapedActual.codeUnitAt(i) != escapedExpected.codeUnitAt(i)) {
      break;
    }
  }
  if (i == minLength) {
    if (escapedExpected.length < escapedActual.length) {
      if (expected.isEmpty) {
        return Rejection(
            actual: literal(actual), which: ['is not the empty string']);
      }
      return Rejection(actual: literal(actual), which: [
        'is too long with unexpected trailing characters:',
        _trailing(escapedActualDisplay, i)
      ]);
    } else {
      if (actual.isEmpty) {
        return Rejection(actual: [
          'an empty string'
        ], which: [
          'is missing all expected characters:',
          _trailing(escapedExpectedDisplay, 0)
        ]);
      }
      return Rejection(actual: literal(actual), which: [
        'is too short with missing trailing characters:',
        _trailing(escapedExpectedDisplay, i)
      ]);
    }
  } else {
    final indentation = ' ' * (i > 10 ? 14 : i);
    return Rejection(actual: literal(actual), which: [
      'differs at offset $i:',
      '${_leading(escapedExpectedDisplay, i)}'
          '${_trailing(escapedExpectedDisplay, i)}',
      '${_leading(escapedActualDisplay, i)}'
          '${_trailing(escapedActualDisplay, i)}',
      '$indentation^'
    ]);
  }
}

/// The truncated beginning of [s] up to the [end] character.
String _leading(String s, int end) =>
    (end > 10) ? '... ${s.substring(end - 10, end)}' : s.substring(0, end);

/// The truncated remainder of [s] starting at the [start] character.
String _trailing(String s, int start) => (start + 10 > s.length)
    ? s.substring(start)
    : '${s.substring(start, start + 10)} ...';

/// Utility function to collapse whitespace runs to single spaces
/// and strip leading/trailing whitespace.
String _collapseWhitespace(String string) {
  var result = StringBuffer();
  var skipSpace = true;
  for (var i = 0; i < string.length; i++) {
    var character = string[i];
    if (_isWhitespace(character)) {
      if (!skipSpace) {
        result.write(' ');
        skipSpace = true;
      }
    } else {
      result.write(character);
      skipSpace = false;
    }
  }
  return result.toString().trim();
}

bool _isWhitespace(String ch) =>
    ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';
