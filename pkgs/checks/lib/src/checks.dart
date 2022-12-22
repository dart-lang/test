// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO Add doc about how failure strings work.
import 'dart:async';

import 'package:test_api/hooks.dart';

import 'describe.dart';

/// A target for checking expectations against a value in a test.
///
/// A Check my have a real value, in which case the expectations can be
/// validated or rejected; or it may be a placeholder, in which case
/// expectations describe what would be checked but cannot be rejected.
///
/// Expectations are defined as extension methods specialized on the generic
/// [T]. Expectations can use the [ContextExtension] to interact with the
/// [Context] for this check.
class Check<T> {
  final Context<T> _context;
  Check._(this._context);

  /// Mark the currently running test as skipped and return a [Check] that will
  /// ignore all expectations.
  ///
  /// Any expectations against the return value will not be checked and will not
  /// be included in the "Expected" or "Actual" string representations of a
  /// failure.
  ///
  /// ```dart
  /// checkThat(actual)
  ///     ..stillChecked()
  ///     ..skip('reason the expectation is temporarily not met').notChecked();
  /// ```
  ///
  /// If `skip` is used in a callback passed to `softCheck` or `describe` it
  /// will still mark the test as skipped, even though failing the expectation
  /// would not have otherwise caused the test to fail.
  Check<T> skip(String message) {
    TestHandle.current.markSkipped(message);
    return Check._(_SkippedContext());
  }
}

/// Creates a [Check] that can be used to validate expectations against [value].
///
/// Expectations that are not satisfied throw a [TestFailure] to interrupt the
/// currently running test and mark it as failed.
///
/// If [because] is passed it will be included as a "Reason:" line in failure
/// messages.
///
/// ```dart
/// checkThat(actual).equals(expected);
/// ```
Check<T> checkThat<T>(T value, {String? because}) => Check._(_TestContext._root(
      value: _Present(value),
      // TODO - switch between "a" and "an"
      label: 'a $T',
      fail: (f) {
        final which = f.rejection.which;
        throw TestFailure([
          ...prefixFirst('Expected: ', f.detail.expected),
          ...prefixFirst('Actual: ', f.detail.actual),
          ...indent(['Actual: ${f.rejection.actual}'], f.detail.depth),
          if (which != null && which.isNotEmpty)
            ...indent(prefixFirst('Which: ', which), f.detail.depth),
          if (because != null) 'Reason: $because',
        ].join('\n'));
      },
      allowAsync: true,
      allowLate: true,
    ));

/// Checks whether [value] satisfies all expectations invoked in [condition].
///
/// Returns `null` if all expectations are satisfied, otherwise returns the
/// [CheckFailure] for the first expectation that fails.
///
/// Asynchronous expectations are not allowed in [condition] and will cause a
/// runtime error if they are used.
CheckFailure? softCheck<T>(T value, void Function(Check<T>) condition) {
  CheckFailure? failure;
  final check = Check<T>._(_TestContext._root(
    value: _Present(value),
    fail: (f) {
      failure = f;
    },
    allowAsync: false,
    allowLate: false,
  ));
  condition(check);
  return failure;
}

/// Checks whether [value] satisfies all expectations invoked in [condition].
///
/// The future will complete to `null` if all expectations are satisfied,
/// otherwise it will complete to the [CheckFailure] for the first expectation
/// that fails.
///
/// In contrast to [softCheck], asynchronous expectations are allowed in
/// [condition].
Future<CheckFailure?> softCheckAsync<T>(
    T value, Future<void> Function(Check<T>) condition) async {
  CheckFailure? failure;
  final check = Check<T>._(_TestContext._root(
    value: _Present(value),
    fail: (f) {
      failure = f;
    },
    allowAsync: true,
    allowLate: false,
  ));
  await condition(check);
  return failure;
}

/// Creates a description of the expectations checked by [condition].
///
/// The strings are individual lines of a description.
/// The description of an expectation may be one or more adjacent lines.
///
/// Matches the "Expected: " lines in the output of a failure message if a value
/// did not meet the last expectation in [condition], without the first labeled
/// line.
Iterable<String> describe<T>(void Function(Check<T>) condition) {
  final context = _TestContext<T>._root(
    value: _Absent(),
    fail: (_) {
      throw UnimplementedError();
    },
    allowAsync: false,
    allowLate: true,
  );
  condition(Check._(context));
  return context.detail(context).expected.skip(1);
}

extension ContextExtension<T> on Check<T> {
  /// The expectations and nesting context for this check.
  Context<T> get context => _context;
}

/// The expectation and nesting context already applied to a [Check].
///
/// This is the surface of interaction for expectation extension method
/// implementations.
///
/// The `expect` and `expectAsync` can test the value and optionally reject it.
/// The `nest` and `nestAsync` can test the value, and also extract some other
/// property from it for further checking.
abstract class Context<T> {
  /// Expect that [predicate] will not return a [Rejection] for the checked
  /// value.
  ///
  /// The property that is asserted by this expectation is described by
  /// [clause]. Often this is a single statement like "equals <1>" or "is
  /// greater than 10", but it may be multiple lines such as describing that an
  /// Iterable contains an element meeting a complex expectation. If any element
  /// in the returned iterable contains a newline it may cause problems with
  /// indentation in the output.
  void expect(
      Iterable<String> Function() clause, Rejection? Function(T) predicate);

  /// Expect that [predicate] will not result in a [Rejection] for the checked
  /// value.
  ///
  /// The property that is asserted by this expectation is described by
  /// [clause]. Often this is a single statement like "equals <1>" or "is
  /// greater than 10", but it may be multiple lines such as describing that an
  /// Iterable contains an element meeting a complex expectation. If any element
  /// in the returned iterable contains a newline it may cause problems with
  /// indentation in the output.
  ///
  /// Some context may disallow asynchronous expectations, for instance in
  /// [softCheck] which must synchronously check the value. In those contexts
  /// this method will throw.
  Future<void> expectAsync<R>(Iterable<String> Function() clause,
      FutureOr<Rejection?> Function(T) predicate);

  /// Report that this check may fail asynchronously at any point in the future.
  ///
  /// A condition that some event _never_ happens will not have any point at
  /// which it can be considered "complete", so a rejection may occur at any
  /// time.
  ///
  /// May not be used from the context for a [Check] created by [softCheck] or
  /// [softCheckAsync]. The only useful effect of a late rejection is to throw a
  /// [TestFailure] when used with a [checkThat] check.
  void expectLate(Iterable<String> Function() clause,
      void Function(T, void Function(Rejection)) predicate);

  /// Extract a property from the value for further checking.
  ///
  /// If the property cannot be extracted, [extract] should return an
  /// [Extracted.rejection] describing the problem. Otherwise it should return
  /// an [Extracted.value].
  ///
  /// The [label] will be used preceding "that:" in a description. Expectations
  /// applied to the returned [Check] will follow the label, indented by two
  /// more spaces.
  ///
  /// If [atSameLevel] is true then [R] should be a subtype of [T], and a
  /// returned [Extracted.value] should be the same instance as passed value.
  /// This may be useful to refine the type for further checks. In this case the
  /// label is used like a single line "clause" passed to [expect], and
  /// expectations applied to the return [Check] will behave as if they were
  /// applied to the Check for this context.
  Check<R> nest<R>(String label, Extracted<R> Function(T) extract,
      {bool atSameLevel = false});

  /// Extract an asynchronous property from the value for further checking.
  ///
  /// If the property cannot be extracted, [extract] should return an
  /// [Extracted.rejection] describing the problem. Otherwise it should return
  /// an [Extracted.value].
  ///
  /// The [label] will be used preceding "that:" in a description. Expectations
  /// applied to the returned [Check] will follow the label, indented by two
  /// more spaces.
  ///
  /// Some context may disallow asynchronous expectations, for instance in
  /// [softCheck] which must synchronously check the value. In those contexts
  /// this method will throw.
  Future<Check<R>> nestAsync<R>(
      String label, FutureOr<Extracted<R>> Function(T) extract);
}

/// A property extracted from a value being checked, or a rejection.
class Extracted<T> {
  final Rejection? rejection;
  final T? value;
  Extracted.rejection({required String actual, Iterable<String>? which})
      : this.rejection = Rejection(actual: actual, which: which),
        this.value = null;
  Extracted.value(this.value) : this.rejection = null;

  Extracted._(this.rejection) : this.value = null;

  Extracted<R> _map<R>(R Function(T) transform) {
    if (rejection != null) return Extracted._(rejection);
    return Extracted.value(transform(value as T));
  }
}

abstract class _Optional<T> {
  R? apply<R extends FutureOr<Rejection?>>(R Function(T) callback);
  Future<Extracted<_Optional<R>>> mapAsync<R>(
      FutureOr<Extracted<R>> Function(T) transform);
  Extracted<_Optional<R>> map<R>(Extracted<R> Function(T) transform);
}

class _Present<T> implements _Optional<T> {
  final T value;
  _Present(this.value);

  @override
  R? apply<R extends FutureOr<Rejection?>>(R Function(T) c) => c(value);

  @override
  Future<Extracted<_Present<R>>> mapAsync<R>(
      FutureOr<Extracted<R>> Function(T) transform) async {
    final transformed = await transform(value);
    return transformed._map((v) => _Present(v));
  }

  @override
  Extracted<_Present<R>> map<R>(Extracted<R> Function(T) transform) =>
      transform(value)._map((v) => _Present(v));
}

class _Absent<T> implements _Optional<T> {
  @override
  R? apply<R extends FutureOr<Rejection?>>(R Function(T) c) => null;

  @override
  Future<Extracted<_Absent<R>>> mapAsync<R>(
          FutureOr<Extracted<R>> Function(T) transform) async =>
      Extracted.value(_Absent<R>());

  @override
  Extracted<_Absent<R>> map<R>(FutureOr<Extracted<R>> Function(T) transform) =>
      Extracted.value(_Absent<R>());
}

class _TestContext<T> implements Context<T>, _ClauseDescription {
  final _Optional<T> _value;

  /// A reference to find the root context which this context is nested under.
  ///
  /// null only for the root context.
  final _TestContext<dynamic>? _parent;

  final List<_ClauseDescription> _clauses;
  final List<_TestContext> _aliases;

  // The "a value" in "a value that:".
  final String _label;

  final void Function(CheckFailure) _fail;

  final bool _allowAsync;
  final bool _allowLate;

  _TestContext._root({
    required _Optional<T> value,
    required void Function(CheckFailure) fail,
    required bool allowAsync,
    required bool allowLate,
    String? label,
  })  : _value = value,
        _label = label ?? '',
        _fail = fail,
        _allowAsync = allowAsync,
        _allowLate = allowLate,
        _parent = null,
        _clauses = [],
        _aliases = [];

  _TestContext._alias(_TestContext original, this._value)
      : _parent = original,
        _clauses = original._clauses,
        _aliases = original._aliases,
        _fail = original._fail,
        _allowAsync = original._allowAsync,
        _allowLate = original._allowLate,
        // Never read from an aliased context because they are never present in
        // `_clauses`.
        _label = '';

  _TestContext._child(this._value, this._label, _TestContext<dynamic> parent)
      : _parent = parent,
        _fail = parent._fail,
        _allowAsync = parent._allowAsync,
        _allowLate = parent._allowLate,
        _clauses = [],
        _aliases = [];

  @override
  void expect(
      Iterable<String> Function() clause, Rejection? Function(T) predicate) {
    _clauses.add(_StringClause(clause));
    final rejection = _value.apply(predicate);
    if (rejection != null) {
      _fail(_failure(rejection));
    }
  }

  @override
  Future<void> expectAsync<R>(Iterable<String> Function() clause,
      FutureOr<Rejection?> Function(T) predicate) async {
    if (!_allowAsync) {
      throw StateError(
          'Async expectations cannot be used in a synchronous check');
    }
    _clauses.add(_StringClause(clause));
    final outstandingWork = TestHandle.current.markPending();
    final rejection = await _value.apply(predicate);
    outstandingWork.complete();
    if (rejection == null) return;
    _fail(_failure(rejection));
  }

  @override
  void expectLate(Iterable<String> Function() clause,
      void Function(T actual, void Function(Rejection) reject) predicate) {
    if (!_allowLate) {
      throw StateError('Late expectations cannot be used for soft checks');
    }
    _clauses.add(_StringClause(clause));
    _value.apply((actual) {
      predicate(actual, (r) => _fail(_failure(r)));
    });
  }

  @override
  Check<R> nest<R>(String label, Extracted<R> Function(T) extract,
      {bool atSameLevel = false}) {
    final result = _value.map(extract);
    final rejection = result.rejection;
    if (rejection != null) {
      _clauses.add(_StringClause(() => [label]));
      _fail(_failure(rejection));
    }
    final value = result.value ?? _Absent<R>();
    final _TestContext<R> context;
    if (atSameLevel) {
      context = _TestContext._alias(this, value);
      _aliases.add(context);
      _clauses.add(_StringClause(() => [label]));
    } else {
      context = _TestContext._child(value, label, this);
      _clauses.add(context);
    }
    return Check._(context);
  }

  @override
  Future<Check<R>> nestAsync<R>(
      String label, FutureOr<Extracted<R>> Function(T) extract) async {
    if (!_allowAsync) {
      throw StateError(
          'Async expectations cannot be used in a synchronous check');
    }
    final outstandingWork = TestHandle.current.markPending();
    final result = await _value.mapAsync(extract);
    outstandingWork.complete();
    final rejection = result.rejection;
    if (rejection != null) {
      _clauses.add(_StringClause(() => [label]));
      _fail(_failure(rejection));
    }
    final value = result.value ?? _Absent<R>();
    final context = _TestContext<R>._child(value, label, this);
    _clauses.add(context);
    return Check._(context);
  }

  CheckFailure _failure(Rejection rejection) =>
      CheckFailure(rejection, () => _root.detail(this));

  _TestContext get _root {
    _TestContext<dynamic> current = this;
    while (current._parent != null) {
      current = current._parent!;
    }
    return current;
  }

  @override
  FailureDetail detail(_TestContext failingContext) {
    assert(_clauses.isNotEmpty);
    final thisContextFailed =
        identical(failingContext, this) || _aliases.contains(failingContext);
    var foundDepth = thisContextFailed ? 0 : -1;
    var foundOverlap = thisContextFailed ? 0 : -1;
    var successfulOverlap = 0;
    final expected = ['$_label that:'];
    for (var clause in _clauses) {
      final details = clause.detail(failingContext);
      expected.addAll(indent(details.expected));
      if (details.depth >= 0) {
        assert(foundDepth == -1);
        assert(foundOverlap == -1);
        foundDepth = details.depth + 1;
        foundOverlap = details._actualOverlap + successfulOverlap + 1;
      } else {
        if (foundDepth == -1) {
          successfulOverlap += details.expected.length;
        }
      }
    }
    return FailureDetail(expected, foundOverlap, foundDepth);
  }
}

/// A context which never runs expectations and can never fail.
class _SkippedContext<T> implements Context<T> {
  @override
  void expect(
      Iterable<String> Function() clause, Rejection? Function(T) predicate) {
    // no-op
  }

  @override
  Future<void> expectAsync<R>(Iterable<String> Function() clause,
      FutureOr<Rejection?> Function(T) predicate) async {
    // no-op
  }

  @override
  void expectLate(Iterable<String> Function() clause,
      void Function(T actual, void Function(Rejection) reject) predicate) {
    // no-op
  }

  @override
  Check<R> nest<R>(String label, Extracted<R> Function(T p1) extract,
      {bool atSameLevel = false}) {
    return Check._(_SkippedContext());
  }

  @override
  Future<Check<R>> nestAsync<R>(
      String label, FutureOr<Extracted<R>> Function(T p1) extract) async {
    return Check._(_SkippedContext());
  }
}

abstract class _ClauseDescription {
  FailureDetail detail(_TestContext failingContext);
}

class _StringClause implements _ClauseDescription {
  final Iterable<String> Function() _expected;
  _StringClause(this._expected);
  @override
  FailureDetail detail(_TestContext failingContext) =>
      FailureDetail(_expected(), -1, -1);
}

/// The result of a Check which is rejected by some expectation.
class CheckFailure {
  /// The specific rejected value within the overall check that caused the
  /// failure.
  ///
  /// The [Rejection.actual] may be a property derived from the value at the
  /// root of the check, for instance a field or an element in a collection.
  final Rejection rejection;

  /// The context within the overall check where an expectation resulted in the
  /// [rejection].
  late final FailureDetail detail = _readDetail();

  final FailureDetail Function() _readDetail;

  CheckFailure(this.rejection, this._readDetail);
}

/// The context of a Check that failed.
///
/// A check may have some number of succeeding expectations, and the failure may
/// be for an expectation against a property derived from the value at the root
/// fo the check. For example, in `checkThat([]).length.equals(1)` the specific
/// value that gets rejected is `0` from the length of the list, and the `Check`
/// that sees the rejection is nested with the label "has length".
class FailureDetail {
  /// A description of all the conditions the checked value was expected to
  /// satisfy.
  ///
  /// Each Check has a label. At the root the label is typically "a <Type>" and
  /// nested conditions get a label based on the condition which extracted a
  /// property for further checks. Each level of nesting is described as
  /// "<label> that:" followed by an indented list of the expectations for that
  /// property.
  ///
  /// For example:
  ///
  ///   a List that:
  ///     has length that:
  ///       equals <3>
  final Iterable<String> expected;

  /// A description of the conditions the checked value satisfied.
  ///
  /// Matches the format of [expected], except it will be cut off after the
  /// label for the check that had a failing expectation. For example, if the
  /// equality check for the length of a list fails:
  ///
  ///   a List that:
  ///     has length that:
  ///
  /// If the check with a failing expectation is the root, returns an empty
  /// list. Instead the "Actual: " value from the rejection can be used without
  /// indentation.
  Iterable<String> get actual =>
      _actualOverlap > 0 ? expected.take(_actualOverlap + 1) : const [];

  /// The number of lines from [expected] which describe conditions that were
  /// successful.
  ///
  /// A check which fails due to a derived property may have some number of
  /// expectations that were checked and satisfied. This field indicates how
  /// many lines of expectations were successful.
  final int _actualOverlap;

  /// The number of times the failing check was nested from the root check.
  ///
  /// Indicates how far the "Actual: " and "Which: " lines from the [Rejection]
  /// should be indented so that they are at the same level of indentation as
  /// the label for the check where the expectation failed.
  ///
  /// For example, if a `List` is expected to and have a certain length
  /// [expected] may be:
  ///
  ///   a List that:
  ///     has length that:
  ///       equals <3>
  ///
  /// If the actual value had an incorrect length, the [depth] will be `1` to
  /// indicate that the failure occurred checking one of the expectations
  /// against the `has length` label.
  final int depth;

  FailureDetail(this.expected, this._actualOverlap, this.depth);
}

/// A description of a value that failed an expectation.
class Rejection {
  /// A description of the actual value as it relates to the expectation.
  ///
  /// This may use [literal] to show a String representation of the value, or it
  /// may be a description of a specific aspect of the value. For instance an
  /// expectation that a Future completes to a value may describe the actual as
  /// "A Future that completes to an error".
  ///
  /// This is printed following an "Actual: " label in the output of a failure
  /// message. The message will be indented to the level of the expectation in
  /// the description, and printed following the descriptions of any
  /// expectations that have already passed.
  final String actual;

  /// A description of the way that [actual] failed to meet the expectation.
  ///
  /// An expectation can provide extra detail, or focus attention on a specific
  /// part of the value. For instance when comparing multiple elements in a
  /// collection, the rejection may describe that the value "has an unequal
  /// value at index 3".
  ///
  /// Lines should be separate values in the iterable, if any element contains a
  /// newline it may cause problems with indentation in the output.
  ///
  /// When provided, this is printed following a "Which: " label at the end of
  /// the output for the failure message.
  final Iterable<String>? which;

  Rejection({required this.actual, this.which});
}
