// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:checks/context.dart';

import 'core.dart' show CoreChecks;

extension StringChecks on Check<String> {
  /// Expects that the value contains [pattern] according to [String.contains];
  void contains(Pattern pattern) {
    context.expect(() => ['contains ${literal(pattern)}'], (actual) {
      if (actual.contains(pattern)) return null;
      return Rejection(
        actual: literal(actual),
        which: ['Does not contain ${literal(pattern)}'],
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
      () => ['starts with ${literal(other)}'],
      (actual) {
        if (actual.startsWith(other)) return null;
        return Rejection(
          actual: literal(actual),
          which: ['does not start with ${literal(other)}'],
        );
      },
    );
  }

  void endsWith(String other) {
    context.expect(
      () => ['ends with ${literal(other)}'],
      (actual) {
        if (actual.endsWith(other)) return null;
        return Rejection(
          actual: literal(actual),
          which: ['does not end with ${literal(other)}'],
        );
      },
    );
  }

  /// Expects that the `String` contains exactly the same code units as
  /// [expected].
  void equals(String expected) {
    context.expect(() => ['equals ${literal(expected)}'],
        (actual) => _findDifference(actual, expected));
  }

  /// Expects that the `String` contains the same characters as [expected] if
  /// both were lower case.
  void equalsIgnoringCase(String expected) {
    context.expect(
        () => ['equals ignoring case ${literal(expected)}'],
        (actual) => _findDifference(
            actual.toLowerCase(), expected.toLowerCase(), actual, expected));
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
        return Rejection(actual: 'an empty string', which: [
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
