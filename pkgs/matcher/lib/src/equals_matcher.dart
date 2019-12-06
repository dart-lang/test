// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'description.dart';
import 'feature_matcher.dart';
import 'interfaces.dart';
import 'util.dart';

/// Returns a matcher that matches if the value is structurally equal to
/// [expected].
///
/// If [expected] is a [Matcher], then it matches using that. Otherwise it tests
/// for equality using `==` on the expected value.
///
/// For [Iterable]s and [Map]s, this will recursively match the elements. To
/// handle cyclic structures a recursion depth [limit] can be provided. The
/// default limit is 100. [Set]s will be compared order-independently.
Matcher equals(expected, [int limit = 100]) => expected is String
    ? _StringEqualsMatcher(expected)
    : _DeepMatcher(expected, limit);

typedef _RecursiveMatcher = List<String> Function(
    dynamic, dynamic, String, int);

/// A special equality matcher for strings.
class _StringEqualsMatcher extends FeatureMatcher<String> {
  final String _value;

  _StringEqualsMatcher(this._value);

  @override
  bool typedMatches(String item, Map matchState) => _value == item;

  @override
  Description describe(Description description) =>
      description.addDescriptionOf(_value);

  @override
  Description describeTypedMismatch(String item,
      Description mismatchDescription, Map matchState, bool verbose) {
    var buff = StringBuffer();
    buff.write('is different.');
    var escapedItem = escape(item);
    var escapedValue = escape(_value);
    var minLength = escapedItem.length < escapedValue.length
        ? escapedItem.length
        : escapedValue.length;
    var start = 0;
    for (; start < minLength; start++) {
      if (escapedValue.codeUnitAt(start) != escapedItem.codeUnitAt(start)) {
        break;
      }
    }
    if (start == minLength) {
      if (escapedValue.length < escapedItem.length) {
        buff.write(' Both strings start the same, but the actual value also'
            ' has the following trailing characters: ');
        _writeTrailing(buff, escapedItem, escapedValue.length);
      } else {
        buff.write(' Both strings start the same, but the actual value is'
            ' missing the following trailing characters: ');
        _writeTrailing(buff, escapedValue, escapedItem.length);
      }
    } else {
      buff.write('\nExpected: ');
      _writeLeading(buff, escapedValue, start);
      _writeTrailing(buff, escapedValue, start);
      buff.write('\n  Actual: ');
      _writeLeading(buff, escapedItem, start);
      _writeTrailing(buff, escapedItem, start);
      buff.write('\n          ');
      for (var i = start > 10 ? 14 : start; i > 0; i--) {
        buff.write(' ');
      }
      buff.write('^\n Differ at offset $start');
    }

    return mismatchDescription.add(buff.toString());
  }

  static void _writeLeading(StringBuffer buff, String s, int start) {
    if (start > 10) {
      buff.write('... ');
      buff.write(s.substring(start - 10, start));
    } else {
      buff.write(s.substring(0, start));
    }
  }

  static void _writeTrailing(StringBuffer buff, String s, int start) {
    if (start + 10 > s.length) {
      buff.write(s.substring(start));
    } else {
      buff.write(s.substring(start, start + 10));
      buff.write(' ...');
    }
  }
}

class _DeepMatcher extends Matcher {
  final Object _expected;
  final int _limit;

  _DeepMatcher(this._expected, [int limit = 1000]) : _limit = limit;

  // Returns a pair (reason, location)
  List<String> _compareIterables(Iterable expected, Object actual,
      _RecursiveMatcher matcher, int depth, String location) {
    if (actual is Iterable) {
      var expectedIterator = expected.iterator;
      var actualIterator = actual.iterator;
      for (var index = 0;; index++) {
        // Advance in lockstep.
        var expectedNext = expectedIterator.moveNext();
        var actualNext = actualIterator.moveNext();

        // If we reached the end of both, we succeeded.
        if (!expectedNext && !actualNext) return null;

        // Fail if their lengths are different.
        var newLocation = '$location[$index]';
        if (!expectedNext) return ['longer than expected', newLocation];
        if (!actualNext) return ['shorter than expected', newLocation];

        // Match the elements.
        var rp = matcher(expectedIterator.current, actualIterator.current,
            newLocation, depth);
        if (rp != null) return rp;
      }
    } else {
      return ['is not Iterable', location];
    }
  }

  List<String> _compareSets(Set expected, Object actual,
      _RecursiveMatcher matcher, int depth, String location) {
    if (actual is Iterable) {
      var other = actual.toSet();

      for (var expectedElement in expected) {
        if (other.every((actualElement) =>
            matcher(expectedElement, actualElement, location, depth) != null)) {
          return ['does not contain $expectedElement', location];
        }
      }

      if (other.length > expected.length) {
        return ['larger than expected', location];
      } else if (other.length < expected.length) {
        return ['smaller than expected', location];
      } else {
        return null;
      }
    } else {
      return ['is not Iterable', location];
    }
  }

  List<String> _recursiveMatch(
      Object expected, Object actual, String location, int depth) {
    // If the expected value is a matcher, try to match it.
    if (expected is Matcher) {
      var matchState = {};
      if (expected.matches(actual, matchState)) return null;

      var description = StringDescription();
      expected.describe(description);
      return ['does not match $description', location];
    } else {
      // Otherwise, test for equality.
      try {
        if (expected == actual) return null;
      } catch (e) {
        // TODO(gram): Add a test for this case.
        return ['== threw "$e"', location];
      }
    }

    if (depth > _limit) return ['recursion depth limit exceeded', location];

    // If _limit is 1 we can only recurse one level into object.
    if (depth == 0 || _limit > 1) {
      if (expected is Set) {
        return _compareSets(
            expected, actual, _recursiveMatch, depth + 1, location);
      } else if (expected is Iterable) {
        return _compareIterables(
            expected, actual, _recursiveMatch, depth + 1, location);
      } else if (expected is Map) {
        if (actual is! Map) return ['expected a map', location];
        var map = actual as Map;
        var err =
            (expected.length == map.length) ? '' : 'has different length and ';
        for (var key in expected.keys) {
          if (!map.containsKey(key)) {
            return ["${err}is missing map key '$key'", location];
          }
        }

        for (var key in map.keys) {
          if (!expected.containsKey(key)) {
            return ["${err}has extra map key '$key'", location];
          }
        }

        for (var key in expected.keys) {
          var rp = _recursiveMatch(
              expected[key], map[key], "$location['$key']", depth + 1);
          if (rp != null) return rp;
        }

        return null;
      }
    }

    var description = StringDescription();

    // If we have recursed, show the expected value too; if not, expect() will
    // show it for us.
    if (depth > 0) {
      description
          .add('was ')
          .addDescriptionOf(actual)
          .add(' instead of ')
          .addDescriptionOf(expected);
      return [description.toString(), location];
    }

    // We're not adding any value to the actual value.
    return ['', location];
  }

  String _match(expected, actual, Map matchState) {
    var rp = _recursiveMatch(expected, actual, '', 0);
    if (rp == null) return null;
    String reason;
    if (rp[0].isNotEmpty) {
      if (rp[1].isNotEmpty) {
        reason = '${rp[0]} at location ${rp[1]}';
      } else {
        reason = rp[0];
      }
    } else {
      reason = '';
    }
    // Cache the failure reason in the matchState.
    addStateInfo(matchState, {'reason': reason});
    return reason;
  }

  @override
  bool matches(item, Map matchState) =>
      _match(_expected, item, matchState) == null;

  @override
  Description describe(Description description) =>
      description.addDescriptionOf(_expected);

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    var reason = matchState['reason'] as String ?? '';
    // If we didn't get a good reason, that would normally be a
    // simple 'is <value>' message. We only add that if the mismatch
    // description is non empty (so we are supplementing the mismatch
    // description).
    if (reason.isEmpty && mismatchDescription.length > 0) {
      mismatchDescription.add('is ').addDescriptionOf(item);
    } else {
      mismatchDescription.add(reason);
    }
    return mismatchDescription;
  }
}
