// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'interfaces.dart';
import 'type_matcher.dart';
import 'util.dart';

/// Returns a matcher that matches the isEmpty property.
const Matcher isEmpty = const _Empty();

class _Empty extends Matcher {
  const _Empty();

  bool matches(item, Map matchState) => item.isEmpty;

  Description describe(Description description) => description.add('empty');
}

/// Returns a matcher that matches the isNotEmpty property.
const Matcher isNotEmpty = const _NotEmpty();

class _NotEmpty extends Matcher {
  const _NotEmpty();

  bool matches(item, Map matchState) => item.isNotEmpty;

  Description describe(Description description) => description.add('non-empty');
}

/// A matcher that matches any null value.
const Matcher isNull = const _IsNull();

/// A matcher that matches any non-null value.
const Matcher isNotNull = const _IsNotNull();

class _IsNull extends Matcher {
  const _IsNull();
  bool matches(item, Map matchState) => item == null;
  Description describe(Description description) => description.add('null');
}

class _IsNotNull extends Matcher {
  const _IsNotNull();
  bool matches(item, Map matchState) => item != null;
  Description describe(Description description) => description.add('not null');
}

/// A matcher that matches the Boolean value true.
const Matcher isTrue = const _IsTrue();

/// A matcher that matches anything except the Boolean value true.
const Matcher isFalse = const _IsFalse();

class _IsTrue extends Matcher {
  const _IsTrue();
  bool matches(item, Map matchState) => item == true;
  Description describe(Description description) => description.add('true');
}

class _IsFalse extends Matcher {
  const _IsFalse();
  bool matches(item, Map matchState) => item == false;
  Description describe(Description description) => description.add('false');
}

/// A matcher that matches the numeric value NaN.
const Matcher isNaN = const _IsNaN();

/// A matcher that matches any non-NaN value.
const Matcher isNotNaN = const _IsNotNaN();

class _IsNaN extends Matcher {
  const _IsNaN();
  bool matches(item, Map matchState) => double.nan.compareTo(item) == 0;
  Description describe(Description description) => description.add('NaN');
}

class _IsNotNaN extends Matcher {
  const _IsNotNaN();
  bool matches(item, Map matchState) => double.nan.compareTo(item) != 0;
  Description describe(Description description) => description.add('not NaN');
}

/// Returns a matches that matches if the value is the same instance
/// as [expected], using [identical].
Matcher same(expected) => new _IsSameAs(expected);

class _IsSameAs extends Matcher {
  final Object _expected;
  const _IsSameAs(this._expected);
  bool matches(item, Map matchState) => identical(item, _expected);
  // If all types were hashable we could show a hash here.
  Description describe(Description description) =>
      description.add('same instance as ').addDescriptionOf(_expected);
}

/// A matcher that matches any value.
const Matcher anything = const _IsAnything();

class _IsAnything extends Matcher {
  const _IsAnything();
  bool matches(item, Map matchState) => true;
  Description describe(Description description) => description.add('anything');
}

/// **DEPRECATED** Use [TypeMatcher] instead.
///
/// Returns a matcher that matches if an object is an instance
/// of [T] (or a subtype).
@Deprecated('Use `const TypeMatcher<MyType>()` instead.')
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
const Matcher returnsNormally = const _ReturnsNormally();

class _ReturnsNormally extends Matcher {
  const _ReturnsNormally();

  bool matches(f, Map matchState) {
    try {
      f();
      return true;
    } catch (e, s) {
      addStateInfo(matchState, {'exception': e, 'stack': s});
      return false;
    }
  }

  Description describe(Description description) =>
      description.add("return normally");

  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    mismatchDescription.add('threw ').addDescriptionOf(matchState['exception']);
    if (verbose) {
      mismatchDescription.add(' at ').add(matchState['stack'].toString());
    }
    return mismatchDescription;
  }
}

/// A matcher for [Map].
const isMap = const TypeMatcher<Map>();

/// A matcher for [List].
const isList = const TypeMatcher<List>();

/// Returns a matcher that matches if an object has a length property
/// that matches [matcher].
Matcher hasLength(matcher) => new _HasLength(wrapMatcher(matcher));

class _HasLength extends Matcher {
  final Matcher _matcher;
  const _HasLength([Matcher matcher]) : this._matcher = matcher;

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
    throw new UnsupportedError('Should never get here');
  }

  Description describe(Description description) =>
      description.add('an object with length of ').addDescriptionOf(_matcher);

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
    throw new UnsupportedError('Should never get here');
  }
}

/// Returns a matcher that matches if the match argument contains the expected
/// value.
///
/// For [String]s this means substring matching;
/// for [Map]s it means the map has the key, and for [Iterable]s
/// it means the iterable has a matching element. In the case of iterables,
/// [expected] can itself be a matcher.
Matcher contains(expected) => new _Contains(expected);

class _Contains extends Matcher {
  final Object _expected;

  const _Contains(this._expected);

  bool matches(item, Map matchState) {
    if (item is String) {
      return item.contains((_expected as Pattern));
    } else if (item is Iterable) {
      if (_expected is Matcher) {
        return item.any((e) => (_expected as Matcher).matches(e, matchState));
      } else {
        return item.contains(_expected);
      }
    } else if (item is Map) {
      return item.containsKey(_expected);
    }
    return false;
  }

  Description describe(Description description) =>
      description.add('contains ').addDescriptionOf(_expected);

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
Matcher isIn(expected) => new _In(expected);

class _In extends Matcher {
  final Object _expected;

  const _In(this._expected);

  bool matches(item, Map matchState) {
    var expected = _expected;
    if (expected is String) {
      return expected.contains(item as Pattern);
    } else if (expected is Iterable) {
      return expected.contains(item);
    } else if (expected is Map) {
      return expected.containsKey(item);
    }
    return false;
  }

  Description describe(Description description) =>
      description.add('is in ').addDescriptionOf(_expected);
}

/// Returns a matcher that uses an arbitrary function that returns
/// true or false for the actual value.
///
/// For example:
///
///     expect(v, predicate((x) => ((x % 2) == 0), "is even"))
Matcher predicate<T>(bool f(T value),
        [String description = 'satisfies function']) =>
    new _Predicate(f, description);

typedef bool _PredicateFunction<T>(T value);

class _Predicate<T> extends Matcher {
  final _PredicateFunction<T> _matcher;
  final String _description;

  _Predicate(this._matcher, this._description);

  bool matches(item, Map matchState) => _matcher(item as T);

  Description describe(Description description) =>
      description.add(_description);
}
