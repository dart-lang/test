// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'interfaces.dart';
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
  final _expected;
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

/// Returns a matcher that matches if an object is an instance
/// of [T] (or a subtype).
///
/// As types are not first class objects in Dart we can only
/// approximate this test by using a generic wrapper class.
///
/// For example, to test whether 'bar' is an instance of type
/// 'Foo', we would write:
///
///     expect(bar, new isInstanceOf<Foo>());
class isInstanceOf<T> extends Matcher {
  const isInstanceOf();

  bool matches(obj, Map matchState) => obj is T;

  Description describe(Description description) =>
      description.add('an instance of $T');
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

/*
 * Matchers for different exception types. Ideally we should just be able to
 * use something like:
 *
 * final Matcher throwsException =
 *     const _Throws(const isInstanceOf<Exception>());
 *
 * Unfortunately instanceOf is not working with dart2js.
 *
 * Alternatively, if static functions could be used in const expressions,
 * we could use:
 *
 * bool _isException(x) => x is Exception;
 * final Matcher isException = const _Predicate(_isException, "Exception");
 * final Matcher throwsException = const _Throws(isException);
 *
 * But currently using static functions in const expressions is not supported.
 * For now the only solution for all platforms seems to be separate classes
 * for each exception type.
 */

abstract class TypeMatcher extends Matcher {
  final String _name;
  const TypeMatcher(this._name);
  Description describe(Description description) => description.add(_name);
}

/// A matcher for Map types.
const Matcher isMap = const _IsMap();

class _IsMap extends TypeMatcher {
  const _IsMap() : super("Map");
  bool matches(item, Map matchState) => item is Map;
}

/// A matcher for List types.
const Matcher isList = const _IsList();

class _IsList extends TypeMatcher {
  const _IsList() : super("List");
  bool matches(item, Map matchState) => item is List;
}

/// Returns a matcher that matches if an object has a length property
/// that matches [matcher].
Matcher hasLength(matcher) => new _HasLength(wrapMatcher(matcher));

class _HasLength extends Matcher {
  final Matcher _matcher;
  const _HasLength([Matcher matcher = null]) : this._matcher = matcher;

  bool matches(item, Map matchState) {
    try {
      // This is harmless code that will throw if no length property
      // but subtle enough that an optimizer shouldn't strip it out.
      if (item.length * item.length >= 0) {
        return _matcher.matches(item.length, matchState);
      }
    } catch (e) {}
    return false;
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
    } catch (e) {}
    return mismatchDescription.add('has no length property');
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
  final _expected;

  const _Contains(this._expected);

  bool matches(item, Map matchState) {
    if (item is String) {
      return item.indexOf(_expected) >= 0;
    } else if (item is Iterable) {
      if (_expected is Matcher) {
        return item.any((e) => _expected.matches(e, matchState));
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
  final _expected;

  const _In(this._expected);

  bool matches(item, Map matchState) {
    if (_expected is String) {
      return _expected.indexOf(item) >= 0;
    } else if (_expected is Iterable) {
      return _expected.any((e) => e == item);
    } else if (_expected is Map) {
      return _expected.containsKey(item);
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
