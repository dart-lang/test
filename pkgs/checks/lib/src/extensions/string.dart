// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import '../../context.dart';

import 'core.dart';

extension StringChecks on Subject<String> {
  /// Expects that the value contains [pattern] according to [String.contains];
  void contains(Pattern pattern) {
    context.expect(() => prefixFirst('contains ', literal(pattern)), (actual) {
      if (actual.contains(pattern)) return null;
      return Rejection(
        which: prefixFirst('Does not contain ', literal(pattern)),
      );
    });
  }

  Subject<int> get length => has((m) => m.length, 'length');

  void isEmpty() {
    context.expect(() => const ['is empty'], (actual) {
      if (actual.isEmpty) return null;
      return Rejection(which: ['is not empty']);
    });
  }

  void isNotEmpty() {
    context.expect(() => const ['is not empty'], (actual) {
      if (actual.isNotEmpty) return null;
      return Rejection(which: ['is empty']);
    });
  }

  void startsWith(Pattern other) {
    context.expect(() => prefixFirst('starts with ', literal(other)), (actual) {
      if (actual.startsWith(other)) return null;
      return Rejection(
        which: prefixFirst('does not start with ', literal(other)),
      );
    });
  }

  void endsWith(String other) {
    context.expect(() => prefixFirst('ends with ', literal(other)), (actual) {
      if (actual.endsWith(other)) return null;
      return Rejection(
        which: prefixFirst('does not end with ', literal(other)),
      );
    });
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
  void matchesPattern(Pattern expected) {
    context.expect(() => prefixFirst('matches ', literal(expected)), (actual) {
      if (expected.allMatches(actual).isNotEmpty) return null;
      return Rejection(
        which: prefixFirst('does not match ', literal(expected)),
      );
    });
  }

  /// Expects that the `String` contains each of the sub strings in expected
  /// in the given order, with any content between them.
  ///
  /// For example, the following will succeed:
  ///
  ///     check('abcdefg').containsInOrder(['a','e']);
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
  void equals(String expected) {
    context.expect(
      () => prefixFirst('equals ', literal(expected)),
      (actual) => _findDifference(actual, expected),
    );
  }

  /// Expects that the `String` contains the same characters as [expected] if
  /// both were lower case.
  void equalsIgnoringCase(String expected) {
    context.expect(
      () => prefixFirst('equals ignoring case ', literal(expected)),
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
  void equalsIgnoringWhitespace(String expected) {
    context.expect(
      () => prefixFirst('equals ignoring whitespace ', literal(expected)),
      (actual) {
        final collapsedActual = _collapseWhitespace(actual);
        final collapsedExpected = _collapseWhitespace(expected);
        return _findDifference(
          collapsedActual,
          collapsedExpected,
          collapsedActual,
          collapsedExpected,
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
    final indentation = ' ' * (i > 10 ? 14 : i);
    return Rejection(
      which: [
        'differs at offset $i:',
        '${_leading(escapedExpectedDisplay, i)}'
            '${_trailing(escapedExpectedDisplay, i)}',
        '${_leading(escapedActualDisplay, i)}'
            '${_trailing(escapedActualDisplay, i)}',
        '$indentation^',
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

extension PatternChecks on Subject<Pattern> {
  /// Extracts the matches found by [allMatches] for further expectations.
  Subject<Iterable<Match>> hasAllMatchesFor(String input, [int start = 0]) {
    return context.nest(() {
      final label = literal(input);
      return prefixFirst(
        'has all matches for ',
        start == 0 ? label : postfixLast(' starting at index $start', label),
      );
    }, (actual) => Extracted.value(actual.allMatches(input, start)));
  }

  /// Extracts the prefix match found by [matchAsPrefix] for further
  /// expectations.
  ///
  /// Expects that [input] matches this pattern as a prefix.
  Subject<Match> hasPrefixMatchFor(String input, [int start = 0]) {
    return context.nest(
      () {
        final label = literal(input);
        return prefixFirst(
          'has prefix match for ',
          start == 0 ? label : postfixLast(' starting at index $start', label),
        );
      },
      (actual) {
        final match = actual.matchAsPrefix(input, start);
        if (match == null) {
          return Extracted.rejection(which: ['did not match as prefix']);
        }
        return Extracted.value(match);
      },
    );
  }
}

extension RegExpChecks on Subject<RegExp> {
  /// Extracts the [isCaseSensitive] property for further expectations.
  Subject<bool> get isCaseSensitive =>
      has((s) => s.isCaseSensitive, 'isCaseSensitive');

  /// Extracts the [isDotAll] property for further expectations.
  Subject<bool> get isDotAll => has((s) => s.isDotAll, 'isDotAll');

  /// Extracts the [isMultiLine] property for further expectations.
  Subject<bool> get isMultiLine => has((s) => s.isMultiLine, 'isMultiLine');

  /// Extracts the [isUnicode] property for further expectations.
  Subject<bool> get isUnicode => has((s) => s.isUnicode, 'isUnicode');

  /// Extracts the [pattern] property for further expectations.
  Subject<String> get pattern => has((s) => s.pattern, 'pattern');

  /// Extracts the first match found by [firstMatch] for further expectations.
  ///
  /// Expects that [input] matches this regular expression.
  Subject<Match> hasFirstMatchFor(String input) {
    return context.nest(
      () => prefixFirst('has first match for ', literal(input)),
      (actual) {
        final match = actual.firstMatch(input);
        if (match == null) {
          return Extracted.rejection(which: ['did not match']);
        }
        return Extracted.value(match);
      },
    );
  }

  /// Extracts the string match found by [stringMatch] for further expectations.
  ///
  /// Expects that [input] matches this regular expression.
  Subject<String> hasStringMatchFor(String input) {
    return context.nest(
      () => prefixFirst('has string match for ', literal(input)),
      (actual) {
        final match = actual.stringMatch(input);
        if (match == null) {
          return Extracted.rejection(which: ['did not match']);
        }
        return Extracted.value(match);
      },
    );
  }

  /// Expects that this regular expression [hasMatch] for [input].
  void hasMatchFor(String input) {
    context.expect(() => prefixFirst('has match for ', literal(input)), (
      actual,
    ) {
      if (actual.hasMatch(input)) return null;
      return Rejection(which: ['did not match']);
    });
  }

  /// Expects that this regular expression does not have a match for [input]
  /// according to [hasMatch].
  void hasNoMatchFor(String input) {
    context.expect(() => prefixFirst('has no match for ', literal(input)), (
      actual,
    ) {
      if (!actual.hasMatch(input)) return null;
      return Rejection(which: ['matched']);
    });
  }
}

extension MatchChecks on Subject<Match> {
  /// Extracts the [end] property for further expectations.
  Subject<int> get end => has((m) => m.end, 'end');

  /// Extracts the [groupCount] property for further expectations.
  Subject<int> get groupCount => has((m) => m.groupCount, 'groupCount');

  /// Extracts the [input] property for further expectations.
  Subject<String> get input => has((m) => m.input, 'input');

  /// Extracts the [pattern] property for further expectations.
  Subject<Pattern> get pattern => has((m) => m.pattern, 'pattern');

  /// Extracts the [start] property for further expectations.
  Subject<int> get start => has((m) => m.start, 'start');

  /// Extracts the group at [index] found by [group] for further expectations.
  Subject<String?> hasGroup(int index) =>
      has((m) => m.group(index), 'group $index');

  /// Extracts the groups at [indices] found by [groups] for further
  /// expectations.
  Subject<List<String?>> hasGroups(List<int> indices) {
    return context.nest(
      () => prefixFirst('has groups ', literal(indices)),
      (actual) => Extracted.value(actual.groups(indices)),
    );
  }
}

extension RegExpMatchChecks on Subject<RegExpMatch> {
  /// Extracts the [groupNames] property for further expectations.
  Subject<Iterable<String>> get groupNames =>
      has((m) => m.groupNames, 'groupNames');

  /// Extracts the [pattern] property for further expectations.
  Subject<RegExp> get pattern => has((m) => m.pattern, 'pattern');

  /// Extracts the named group [name] found by [namedGroup] for further
  /// expectations.
  Subject<String?> hasNamedGroup(String name) =>
      has((m) => m.namedGroup(name), 'named group "$name"');
}
