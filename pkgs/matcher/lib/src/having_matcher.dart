// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'custom_matcher.dart';
import 'interfaces.dart';
import 'type_matcher.dart';
import 'util.dart';

/// A package-private [TypeMatcher] implementation that handles is returned
/// by calls to [TypeMatcher.having].
class HavingMatcher<T> implements TypeMatcher<T> {
  final TypeMatcher<T> _parent;
  final List<_FunctionMatcher> _functionMatchers;

  HavingMatcher(TypeMatcher<T> parent, String description,
      Object feature(T source), Object matcher,
      [Iterable<_FunctionMatcher> existing])
      : this._parent = parent,
        this._functionMatchers = <_FunctionMatcher>[]
          ..addAll(existing ?? [])
          ..add(new _FunctionMatcher<T>(description, feature, matcher));

  TypeMatcher<T> having(
          Object feature(T source), String description, Object matcher) =>
      new HavingMatcher(
          _parent, description, feature, matcher, _functionMatchers);

  bool matches(item, Map matchState) {
    for (var matcher in <Matcher>[_parent].followedBy(_functionMatchers)) {
      if (!matcher.matches(item, matchState)) {
        addStateInfo(matchState, {'matcher': matcher});
        return false;
      }
    }
    return true;
  }

  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    var matcher = matchState['matcher'] as Matcher;
    matcher.describeMismatch(
        item, mismatchDescription, matchState['state'] as Map, verbose);
    return mismatchDescription;
  }

  Description describe(Description description) => description
      .add('')
      .addDescriptionOf(_parent)
      .add(' with ')
      .addAll('', ' and ', '', _functionMatchers);
}

class _FunctionMatcher<T> extends CustomMatcher {
  final dynamic Function(T value) _feature;

  _FunctionMatcher(String name, this._feature, matcher)
      : super('`$name`:', '`$name`', matcher);

  @override
  Object featureValueOf(covariant T actual) => _feature(actual);
}
