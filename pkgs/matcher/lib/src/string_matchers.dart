// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'feature_matcher.dart';
import 'interfaces.dart';

/// Returns a matcher which matches if the match argument is a string and
/// is equal to [value] when compared case-insensitively.
Matcher equalsIgnoringCase(String value) => new _IsEqualIgnoringCase(value);

class _IsEqualIgnoringCase extends FeatureMatcher<String> {
  final String _value;
  final String _matchValue;

  _IsEqualIgnoringCase(String value)
      : _value = value,
        _matchValue = value.toLowerCase();

  bool typedMatches(String item, Map matchState) =>
      _matchValue == item.toLowerCase();

  Description describe(Description description) =>
      description.addDescriptionOf(_value).add(' ignoring case');
}

/// Returns a matcher which matches if the match argument is a string and
/// is equal to [value], ignoring whitespace.
///
/// In this matcher, "ignoring whitespace" means comparing with all runs of
/// whitespace collapsed to single space characters and leading and trailing
/// whitespace removed.
///
/// For example, the following will all match successfully:
///
///     expect("hello   world", equalsIgnoringWhitespace("hello world"));
///     expect("  hello world", equalsIgnoringWhitespace("hello world"));
///     expect("hello world  ", equalsIgnoringWhitespace("hello world"));
///
/// The following will not match:
///
///     expect("helloworld", equalsIgnoringWhitespace("hello world"));
///     expect("he llo world", equalsIgnoringWhitespace("hello world"));
Matcher equalsIgnoringWhitespace(String value) =>
    new _IsEqualIgnoringWhitespace(value);

class _IsEqualIgnoringWhitespace extends FeatureMatcher<String> {
  final String _value;
  final String _matchValue;

  _IsEqualIgnoringWhitespace(String value)
      : _value = value,
        _matchValue = collapseWhitespace(value);

  bool typedMatches(String item, Map matchState) =>
      _matchValue == collapseWhitespace(item);

  Description describe(Description description) =>
      description.addDescriptionOf(_matchValue).add(' ignoring whitespace');

  Description describeTypedMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    return mismatchDescription
        .add('is ')
        .addDescriptionOf(collapseWhitespace(item))
        .add(' with whitespace compressed');
  }
}

/// Returns a matcher that matches if the match argument is a string and
/// starts with [prefixString].
Matcher startsWith(String prefixString) => new _StringStartsWith(prefixString);

class _StringStartsWith extends FeatureMatcher<String> {
  final String _prefix;

  const _StringStartsWith(this._prefix);

  bool typedMatches(item, Map matchState) => item.startsWith(_prefix);

  Description describe(Description description) =>
      description.add('a string starting with ').addDescriptionOf(_prefix);
}

/// Returns a matcher that matches if the match argument is a string and
/// ends with [suffixString].
Matcher endsWith(String suffixString) => new _StringEndsWith(suffixString);

class _StringEndsWith extends FeatureMatcher<String> {
  final String _suffix;

  const _StringEndsWith(this._suffix);

  bool typedMatches(item, Map matchState) => item.endsWith(_suffix);

  Description describe(Description description) =>
      description.add('a string ending with ').addDescriptionOf(_suffix);
}

/// Returns a matcher that matches if the match argument is a string and
/// contains a given list of [substrings] in relative order.
///
/// For example, `stringContainsInOrder(["a", "e", "i", "o", "u"])` will match
/// "abcdefghijklmnopqrstuvwxyz".

Matcher stringContainsInOrder(List<String> substrings) =>
    new _StringContainsInOrder(substrings);

class _StringContainsInOrder extends FeatureMatcher<String> {
  final List<String> _substrings;

  const _StringContainsInOrder(this._substrings);

  bool typedMatches(item, Map matchState) {
    var fromIndex = 0;
    for (var s in _substrings) {
      fromIndex = item.indexOf(s, fromIndex);
      if (fromIndex < 0) return false;
    }
    return true;
  }

  Description describe(Description description) => description.addAll(
      'a string containing ', ', ', ' in order', _substrings);
}

/// Returns a matcher that matches if the match argument is a string and
/// matches the regular expression given by [re].
///
/// [re] can be a [RegExp] instance or a [String]; in the latter case it will be
/// used to create a RegExp instance.
Matcher matches(re) => new _MatchesRegExp(re);

class _MatchesRegExp extends FeatureMatcher<String> {
  RegExp _regexp;

  _MatchesRegExp(re) {
    if (re is String) {
      _regexp = new RegExp(re);
    } else if (re is RegExp) {
      _regexp = re;
    } else {
      throw new ArgumentError('matches requires a regexp or string');
    }
  }

  bool typedMatches(item, Map matchState) => _regexp.hasMatch(item);

  Description describe(Description description) =>
      description.add("match '${_regexp.pattern}'");
}

/// Utility function to collapse whitespace runs to single spaces
/// and strip leading/trailing whitespace.
String collapseWhitespace(String string) {
  var result = new StringBuffer();
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
