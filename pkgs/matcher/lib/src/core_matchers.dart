// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'feature_matcher.dart';
import 'interfaces.dart';
import 'type_matcher.dart';
import 'util.dart';

/// Returns a matcher that matches the isEmpty property.
const Matcher isEmpty = _Empty();

class _Empty extends Matcher {
  const _Empty();

  @override
  bool matches(item, Map matchState) => item.isEmpty;

  @override
  Description describe(Description description) => description.add('empty');
}

/// Returns a matcher that matches the isNotEmpty property.
const Matcher isNotEmpty = _NotEmpty();

class _NotEmpty extends Matcher {
  const _NotEmpty();

  @override
  bool matches(item, Map matchState) => item.isNotEmpty;

  @override
  Description describe(Description description) => description.add('non-empty');
}

/// A matcher that matches any null value.
const Matcher isNull = _IsNull();

/// A matcher that matches any non-null value.
const Matcher isNotNull = _IsNotNull();

class _IsNull extends Matcher {
  const _IsNull();
  @override
  bool matches(item, Map matchState) => item == null;
  @override
  Description describe(Description description) => description.add('null');
}

class _IsNotNull extends Matcher {
  const _IsNotNull();
  @override
  bool matches(item, Map matchState) => item != null;
  @override
  Description describe(Description description) => description.add('not null');
}

/// A matcher that matches the Boolean value true.
const Matcher isTrue = _IsTrue();

/// A matcher that matches anything except the Boolean value true.
const Matcher isFalse = _IsFalse();

class _IsTrue extends Matcher {
  const _IsTrue();
  @override
  bool matches(item, Map matchState) => item == true;
  @override
  Description describe(Description description) => description.add('true');
}

class _IsFalse extends Matcher {
  const _IsFalse();
  @override
  bool matches(item, Map matchState) => item == false;
  @override
  Description describe(Description description) => description.add('false');
}

/// A matcher that matches the numeric value NaN.
const Matcher isNaN = _IsNaN();

/// A matcher that matches any non-NaN value.
const Matcher isNotNaN = _IsNotNaN();

class _IsNaN extends FeatureMatcher<num> {
  const _IsNaN();
  @override
  bool typedMatches(num item, Map matchState) =>
      double.nan.compareTo(item) == 0;
  @override
  Description describe(Description description) => description.add('NaN');
}

class _IsNotNaN extends FeatureMatcher<num> {
  const _IsNotNaN();
  @override
  bool typedMatches(num item, Map matchState) =>
      double.nan.compareTo(item) != 0;
  @override
  Description describe(Description description) => description.add('not NaN');
}

/// Returns a matches that matches if the value is the same instance
/// as [expected], using [identical].
Matcher same(expected) => _IsSameAs(expected);

class _IsSameAs extends Matcher {
  final Object _expected;
  const _IsSameAs(this._expected);
  @override
  bool matches(item, Map matchState) => identical(item, _expected);
  // If all types were hashable we could show a hash here.
  @override
  Description describe(Description description) =>
      description.add('same instance as ').addDescriptionOf(_expected);
}

/// A matcher that matches any value.
const Matcher anything = _IsAnything();

class _IsAnything extends Matcher {
  const _IsAnything();
  @override
  bool matches(item, Map matchState) => true;
  @override
  Description describe(Description description) => description.add('anything');
}

/// **DEPRECATED** Use [isA] instead.
///
/// A matcher that matches if an object is an instance of [T] (or a subtype).
@Deprecated('Use `isA<MyType>()` instead.')
// ignore: camel_case_types
class isInstanceOf<T> extends TypeMatcher<T> {
  const isInstanceOf();
}

/// A matcher that matches a function call against no exception.
///
/// The function will be called once. Any exceptions will be silently swallowed.
/// The value passed to expect() should be a reference to the function.
/// Note that the function cannot take arguments; to handle this
/// a wrapper will have to be created.
const Matcher returnsNormally = _ReturnsNormally();

class _ReturnsNormally extends FeatureMatcher<Function> {
  const _ReturnsNormally();

  @override
  bool typedMatches(Function f, Map matchState) {
    try {
      f();
      return true;
    } catch (e, s) {
      addStateInfo(matchState, {'exception': e, 'stack': s});
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('return normally');

  @override
  Description describeTypedMismatch(Function item,
      Description mismatchDescription, Map matchState, bool verbose) {
    mismatchDescription.add('threw ').addDescriptionOf(matchState['exception']);
    if (verbose) {
      mismatchDescription.add(' at ').add(matchState['stack'].toString());
    }
    return mismatchDescription;
  }
}

/// A matcher for [Map].
const isMap = TypeMatcher<Map>();

/// A matcher for [List].
const isList = TypeMatcher<List>();

/// Returns a matcher that matches if an object has a length property
/// that matches [matcher].
Matcher hasLength(matcher) => _HasLength(wrapMatcher(matcher));

class _HasLength extends Matcher {
  final Matcher _matcher;
  const _HasLength([Matcher matcher]) : _matcher = matcher;

  @override
  bool matches(item, Map matchState) {
    try {
      // This is harmless code that will throw if no length property
      // but subtle enough that an optimizer shouldn't strip it out.
      if (item.length * item.length >= 0) {
        return _matcher.matches(item.length, matchState);
      }
    } catch (e) {
      return false;
    }
    throw UnsupportedError('Should never get here');
  }

  @override
  Description describe(Description description) =>
      description.add('an object with length of ').addDescriptionOf(_matcher);

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    try {
      // We want to generate a different description if there is no length
      // property; we use the same trick as in matches().
      if (item.length * item.length >= 0) {
        return mismatchDescription
            .add('has length of ')
            .addDescriptionOf(item.length);
      }
    } catch (e) {
      return mismatchDescription.add('has no length property');
    }
    throw UnsupportedError('Should never get here');
  }
}

/// Returns a matcher that matches if the match argument contains the expected
/// value.
///
/// For [String]s this means substring matching;
/// for [Map]s it means the map has the key, and for [Iterable]s
/// it means the iterable has a matching element. In the case of iterables,
/// [expected] can itself be a matcher.
Matcher contains(expected) => _Contains(expected);

class _Contains extends Matcher {
  final Object _expected;

  const _Contains(this._expected);

  @override
  bool matches(item, Map matchState) {
    var expected = _expected;
    if (item is String) {
      return expected is Pattern && item.contains(expected);
    } else if (item is Iterable) {
      if (expected is Matcher) {
        return item.any((e) => expected.matches(e, matchState));
      } else {
        return item.contains(_expected);
      }
    } else if (item is Map) {
      return item.containsKey(_expected);
    }
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('contains ').addDescriptionOf(_expected);

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    if (item is String || item is Iterable || item is Map) {
      return super
          .describeMismatch(item, mismatchDescription, matchState, verbose);
    } else {
      return mismatchDescription.add('is not a string, map or iterable');
    }
  }
}

/// Returns a matcher that matches if the match argument is in
/// the expected value. This is the converse of [contains].
Matcher isIn(expected) {
  if (expected is Iterable) {
    return _In(expected, expected.contains);
  } else if (expected is String) {
    return _In<Pattern>(expected, expected.contains);
  } else if (expected is Map) {
    return _In(expected, expected.containsKey);
  }

  throw ArgumentError.value(
      expected, 'expected', 'Only Iterable, Map, and String are supported.');
}

class _In<T> extends FeatureMatcher<T> {
  final Object _source;
  final bool Function(T) _containsFunction;

  const _In(this._source, this._containsFunction);

  @override
  bool typedMatches(T item, Map matchState) => _containsFunction(item);

  @override
  Description describe(Description description) =>
      description.add('is in ').addDescriptionOf(_source);
}

/// Returns a matcher that uses an arbitrary function that returns
/// true or false for the actual value.
///
/// For example:
///
///     expect(v, predicate((x) => ((x % 2) == 0), "is even"))
Matcher predicate<T>(bool Function(T) f,
        [String description = 'satisfies function']) =>
    _Predicate(f, description);

typedef _PredicateFunction<T> = bool Function(T value);

class _Predicate<T> extends FeatureMatcher<T> {
  final _PredicateFunction<T> _matcher;
  final String _description;

  _Predicate(this._matcher, this._description);

  @override
  bool typedMatches(T item, Map matchState) => _matcher(item);

  @override
  Description describe(Description description) =>
      description.add(_description);
}
