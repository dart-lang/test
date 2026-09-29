// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import '../../context.dart';

import 'core.dart';

extension StringChecks on Subject<String> {
  /// Expects that the value contains [pattern] according to [String.contains];
  ///
  /// {@example /example/string/string/contains.dart}
  void contains(Pattern pattern) {
    context.expect(
      () => prefixFirst('contains ', literal(pattern)),
      predicateNoun: () {
        final l = literal(pattern).singleOrNull;
        return l != null ? 'a string that contains $l' : null;
      },
      (actual) {
        if (actual.contains(pattern)) return null;
        return Rejection(
          which: prefixFirst('does not contain ', literal(pattern)),
        );
      },
    );
  }

  /// A [Subject] for the number of code units in the `String`.
  ///
  /// {@example /example/string/string/length.dart}
  Subject<int> get length => has((m) => m.length, 'length');

  /// Expects that the `String` has no characters.
  ///
  /// {@example /example/string/string/is_empty.dart}
  void get isEmpty {
    context.expect(
      () => const ['is empty'],
      predicateNoun: () => 'an empty string',
      (actual) {
        if (actual.isEmpty) return null;
        return Rejection(which: ['is not empty']);
      },
    );
  }

  /// Expects that the `String` has at least one character.
  ///
  /// {@example /example/string/string/is_not_empty.dart}
  void get isNotEmpty {
    context.expect(
      () => const ['is not empty'],
      predicateNoun: () => 'a non-empty string',
      (actual) {
        if (actual.isNotEmpty) return null;
        return Rejection(which: ['is empty']);
      },
    );
  }

  /// Expects that the `String` starts with [other] according to
  /// [String.startsWith].
  ///
  /// {@example /example/string/string/starts_with.dart}
  void startsWith(Pattern other) {
    context.expect(
      () => prefixFirst('starts with ', literal(other)),
      predicateNoun: () {
        final l = literal(other).singleOrNull;
        return l != null ? 'a string starting with $l' : null;
      },
      (actual) {
        if (actual.startsWith(other)) return null;
        return Rejection(
          which: prefixFirst('does not start with ', literal(other)),
        );
      },
    );
  }

  /// Expects that the `String` ends with [other] according to
  /// [String.endsWith].
  ///
  /// {@example /example/string/string/ends_with.dart}
  void endsWith(String other) {
    context.expect(
      () => prefixFirst('ends with ', literal(other)),
      predicateNoun: () {
        final l = literal(other).singleOrNull;
        return l != null ? 'a string ending with $l' : null;
      },
      (actual) {
        if (actual.endsWith(other)) return null;
        return Rejection(
          which: prefixFirst('does not end with ', literal(other)),
        );
      },
    );
  }

  /// Expects that the string matches the pattern [expected].
  ///
  /// Fails if [expected] returns an empty result from calling `allMatches` with
  /// the value.
  ///
  /// ```
  /// check(actual).matchesPattern('abc');
  /// check(actual).matchesPattern(RegExp(r'\d'));
  /// ```
  ///
  /// {@example /example/string/string/matches_pattern.dart}
  void matchesPattern(Pattern expected) {
    context.expect(
      () => prefixFirst('matches ', literal(expected)),
      predicateNoun: () {
        final l = literal(expected).singleOrNull;
        return l != null ? 'a string matching $l' : null;
      },
      (actual) {
        if (expected.allMatches(actual).isNotEmpty) return null;
        return Rejection(
          which: prefixFirst('does not match ', literal(expected)),
        );
      },
    );
  }

  /// Expects that the `String` contains each of the sub strings in expected
  /// in the given order, with any content between them.
  ///
  /// For example, the following will succeed:
  ///
  ///     check('abcdefg').containsInOrder(['a','e']);
  ///
  /// {@example /example/string/string/contains_in_order.dart}
  void containsInOrder(Iterable<String> expected) {
    context.expect(
      () => prefixFirst('contains, in order: ', literal(expected)),
      (actual) {
        var fromIndex = 0;
        for (var s in expected) {
          var index = actual.indexOf(s, fromIndex);
          if (index < 0) {
            return Rejection(
              which: [
                ...prefixFirst(
                  'does not have a match for the substring ',
                  literal(s),
                ),
                if (fromIndex != 0)
                  'following the other matches up to character $fromIndex',
              ],
            );
          }
          fromIndex = index + s.length;
        }
        return null;
      },
    );
  }

  /// Expects that the `String` contains exactly the same code units as
  /// [expected].
  ///
  /// {@example /example/string/string/equals.dart}
  void equals(String expected) {
    context.expect(
      () => prefixFirst('equals ', literal(expected)),
      predicateNoun: () => literal(expected).singleOrNull,
      (actual) => _findDifference(actual, expected),
    );
  }

  /// Expects that the `String` contains the same characters as [expected] if
  /// both were lower case.
  ///
  /// {@example /example/string/string/equals_ignoring_case.dart}
  void equalsIgnoringCase(String expected) {
    context.expect(
      () => prefixFirst('equals ignoring case ', literal(expected)),
      predicateNoun: () {
        final l = literal(expected).singleOrNull;
        return l != null ? 'a string equal to $l ignoring case' : null;
      },
      (actual) => _findDifference(
        actual.toLowerCase(),
        expected.toLowerCase(),
        actual,
        expected,
      ),
    );
  }

  /// Expects that the `String` contains the same content as [expected],
  /// ignoring differences in whitsepace.
  ///
  /// All runs of whitespace characters are collapsed to a single space, and
  /// leading and traiilng whitespace are removed before comparison.
  ///
  /// For example the following will succeed:
  ///
  ///     check(' hello   world ').equalsIgnoringWhitespace('hello world');
  ///
  /// While the following will fail:
  ///
  ///     check('helloworld').equalsIgnoringWhitespace('hello world');
  ///     check('he llo world').equalsIgnoringWhitespace('hello world');
  ///
  /// {@example /example/string/string/equals_ignoring_whitespace.dart}
  void equalsIgnoringWhitespace(String expected) {
    context.expect(
      () => prefixFirst('equals ignoring whitespace ', literal(expected)),
      (actual) {
        final collapsedActual = _collapseWhitespace(actual);
        final difference = _findDifference(
          collapsedActual,
          _collapseWhitespace(expected),
        );
        if (difference == null) return null;
        // The difference is found between the collapsed strings, so any
        // offsets it reports are offsets into `collapsedActual`, not into the
        // original value. Name the collapsed value so that the reported
        // offsets can be matched up with it.
        return Rejection(
          which: [
            ...prefixFirst(
              'with whitespace collapsed to ',
              postfixLast(' it:', literal(collapsedActual)),
            ),
            ...indent(difference.which!),
          ],
        );
      },
    );
  }
}

Rejection? _findDifference(
  String actual,
  String expected, [
  String? actualDisplay,
  String? expectedDisplay,
]) {
  if (actual == expected) return null;
  final escapedActual = escape(actual);
  final escapedExpected = escape(expected);
  final escapedActualDisplay = actualDisplay != null
      ? escape(actualDisplay)
      : escapedActual;
  final escapedExpectedDisplay = expectedDisplay != null
      ? escape(expectedDisplay)
      : escapedExpected;
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
        return Rejection(which: ['is not the empty string']);
      }
      return Rejection(
        which: [
          'is too long with unexpected trailing characters:',
          _trailing(escapedActualDisplay, i),
        ],
      );
    } else {
      if (actual.isEmpty) {
        return Rejection(
          actual: ['an empty string'],
          which: [
            'is missing all expected characters:',
            _trailing(escapedExpectedDisplay, 0),
          ],
        );
      }
      return Rejection(
        which: [
          'is too short with missing trailing characters:',
          _trailing(escapedExpectedDisplay, i),
        ],
      );
    }
  } else {
    final markerIndent = ' ' * (i > 10 ? 14 : i);
    return Rejection(
      which: [
        'differs at offset $i:',
        ...indent([
          '${_leading(escapedExpectedDisplay, i)}'
              '${_trailing(escapedExpectedDisplay, i)}',
          '${_leading(escapedActualDisplay, i)}'
              '${_trailing(escapedActualDisplay, i)}',
          '$markerIndent^',
        ]),
      ],
    );
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
