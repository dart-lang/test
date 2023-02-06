// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO Add doc about how failure strings work.
import 'dart:async';

import 'package:meta/meta.dart' as meta;
import 'package:test_api/hooks.dart';

import 'describe.dart';

/// A target for checking expectations against a value in a test.
///
/// A subject my have a real value, in which case the expectations can be
/// validated or rejected; or it may be a placeholder, in which case
/// expectations describe what would be checked but cannot be rejected.
///
/// Expectations are defined as extension methods specialized on the generic
/// [T]. Expectations can use the [ContextExtension] to interact with the
/// [Context] for this subject.
class Subject<T> {
  final Context<T> _context;
  Subject._(this._context);
}

extension SkipExtension<T> on Subject<T> {
  /// Mark the currently running test as skipped and return a [Subject] that
  /// will ignore all expectations.
  ///
  /// Any expectations against the return value will not be checked and will not
  /// be included in the "Expected" or "Actual" string representations of a
  /// failure.
  ///
  /// ```dart
  /// check(actual)
  ///     ..stillChecked()
  ///     ..skip('reason the expectation is temporarily not met').notChecked();
  /// ```
  ///
  /// If `skip` is used in a callback passed to `softCheck` or `describe` it
  /// will still mark the test as skipped, even though failing the expectation
  /// would not have otherwise caused the test to fail.
  Subject<T> skip(String message) {
    TestHandle.current.markSkipped(message);
    return Subject._(_SkippedContext());
  }
}

/// Creates a [Subject] that can be used to validate expectations against
/// [value], with an exception upon a failed expectation.
///
/// Expectations that are not satisfied throw a [TestFailure] to interrupt the
/// currently running test and mark it as failed.
///
/// If [because] is passed it will be included as a "Reason:" line in failure
/// messages.
///
/// ```dart
/// check(actual).equals(expected);
/// ```
@meta.useResult
Subject<T> check<T>(T value, {String? because}) => Subject._(_TestContext._root(
      value: _Present(value),
      // TODO - switch between "a" and "an"
      label: 'a $T',
      fail: (f) {
        final which = f.rejection.which;
        throw TestFailure([
          ...prefixFirst('Expected: ', f.detail.expected),
          ...prefixFirst('Actual: ', f.detail.actual),
          ...indent(
              prefixFirst('Actual: ', f.rejection.actual), f.detail.depth),
          if (which != null && which.isNotEmpty)
            ...indent(prefixFirst('Which: ', which), f.detail.depth),
          if (because != null) 'Reason: $because',
        ].join('\n'));
      },
      allowAsync: true,
      allowUnawaited: true,
    ));

/// Checks whether [value] satisfies all expectations invoked in [condition],
/// without throwing an exception.
///
/// Returns `null` if all expectations are satisfied, otherwise returns the
/// [CheckFailure] for the first expectation that fails.
///
/// Asynchronous expectations are not allowed in [condition] and will cause a
/// runtime error if they are used.
CheckFailure? softCheck<T>(T value, Condition<T> condition) {
  CheckFailure? failure;
  final subject = Subject<T>._(_TestContext._root(
    value: _Present(value),
    fail: (f) {
      failure = f;
    },
    allowAsync: false,
    allowUnawaited: false,
  ));
  condition.apply(subject);
  return failure;
}

/// Checks whether [value] satisfies all expectations invoked in [condition],
/// without throwing an exception.
///
/// The future will complete to `null` if all expectations are satisfied,
/// otherwise it will complete to the [CheckFailure] for the first expectation
/// that fails.
///
/// In contrast to [softCheck], asynchronous expectations are allowed in
/// [condition].
Future<CheckFailure?> softCheckAsync<T>(T value, Condition<T> condition) async {
  CheckFailure? failure;
  final subject = Subject<T>._(_TestContext._root(
    value: _Present(value),
    fail: (f) {
      failure = f;
    },
    allowAsync: true,
    allowUnawaited: false,
  ));
  await condition.applyAsync(subject);
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
///
/// Asynchronous expectations are not allowed in [condition], for async
/// conditions use [describeAsync].
Iterable<String> describe<T>(Condition<T> condition) {
  final context = _TestContext<T>._root(
    value: _Absent(),
    fail: (_) {
      throw UnimplementedError();
    },
    allowAsync: false,
    allowUnawaited: true,
  );
  condition.apply(Subject._(context));
  return context.detail(context).expected.skip(1);
}

/// Creates a description of the expectations checked by [condition].
///
/// The strings are individual lines of a description.
/// The description of an expectation may be one or more adjacent lines.
///
/// Matches the "Expected: " lines in the output of a failure message if a value
/// did not meet the last expectation in [condition], without the first labeled
/// line.
///
/// In contrast to [describe], asynchronous expectations are allowed in
/// [condition].
Future<Iterable<String>> describeAsync<T>(Condition<T> condition) async {
  final context = _TestContext<T>._root(
    value: _Absent(),
    fail: (_) {
      throw UnimplementedError();
    },
    allowAsync: true,
    allowUnawaited: true,
  );
  await condition.applyAsync(Subject._(context));
  return context.detail(context).expected.skip(1);
}

/// A set of expectations that are checked against the value when applied to a
/// [Subject].
abstract class Condition<T> {
  void apply(Subject<T> subject);
  Future<void> applyAsync(Subject<T> subject);
}

ConditionSubject<T> it<T>() => ConditionSubject._();

extension ContextExtension<T> on Subject<T> {
  /// The expectations and nesting context for this subject.
  Context<T> get context => _context;
}

/// The expectation and nesting context already applied to a [Subject].
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

  /// Expect that [predicate] will not invoke the passed callback with a
  /// [Rejection] at any point.
  ///
  /// In contrast to [expectAsync], a rejection is reported through a
  /// callback instead of through a returned Future. The callback may be invoked
  /// at any point that the failure surfaces.
  ///
  /// This may be useful for a condition checking that some event _never_
  /// happens. If there is no specific point where it is know to be safe to stop
  /// listening for the event, there is no way to complete a returned future and
  /// consider the check "complete".
  ///
  /// May not be used from the context for a [Subject] created by [softCheck] or
  /// [softCheckAsync]. The only useful effect of a late rejection is to throw a
  /// [TestFailure] when used with a [check] subject. Most conditions should
  /// prefer to use [expect] or [expectAsync].
  void expectUnawaited(Iterable<String> Function() clause,
      void Function(T, void Function(Rejection)) predicate);

  /// Extract a property from the value for further checking.
  ///
  /// If the property cannot be extracted, [extract] should return an
  /// [Extracted.rejection] describing the problem. Otherwise it should return
  /// an [Extracted.value].
  ///
  /// The [label] output will be used preceding "that:" in a description if
  /// there are further expectations checked on the returned subject, or on it's
  /// own otherwise.
  /// Expectations applied to the returned [Subject] will follow the label,
  /// indented by two more spaces.
  ///
  /// If [atSameLevel] is true then [R] should be a subtype of [T], and a
  /// returned [Extracted.value] should be the same instance as the passed
  /// value, or an object which is is equivalent but has a type which is more
  /// convenient to test. In this case expectations applied to the return
  /// [Subject] will behave as if they were applied to the subject for this
  /// context. The [label] will be used as if it were a "clause" argument passed
  /// to [expect]. If the label is empty, the clause will be omitted. The
  /// label should only be left empty if the value extraction cannot fail.
  Subject<R> nest<R>(
      Iterable<String> Function() label, Extracted<R> Function(T) extract,
      {bool atSameLevel = false});

  /// Extract an asynchronous property from the value for further checking.
  ///
  /// If the property cannot be extracted, [extract] should return an
  /// [Extracted.rejection] describing the problem. Otherwise it should return
  /// an [Extracted.value].
  ///
  /// The [label] output will be used preceding "that:" in a description if
  /// there are further expectations checked on the returned subject, or on it's
  /// own otherwise.
  /// Expectations applied to the returned [Subject] will follow the label,
  /// indented by two more spaces.
  ///
  /// Some context may disallow asynchronous expectations, for instance in
  /// [softCheck] which must synchronously check the value. In those contexts
  /// this method will throw.
  Future<Subject<R>> nestAsync<R>(Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T) extract);
}

/// A property extracted from a value being checked, or a rejection.
class Extracted<T> {
  final Rejection? rejection;
  final T? value;

  /// Creates a rejected extraction to indicate a failure trying to read the
  /// value.
  ///
  /// When a nesting is rejected with an omitted or empty [actual] argument, it
  /// will be filled in with the [literal] representation of the value.
  Extracted.rejection(
      {Iterable<String> actual = const [], Iterable<String>? which})
      : rejection = Rejection(actual: actual, which: which),
        value = null;
  Extracted.value(T this.value) : rejection = null;

  Extracted._(Rejection this.rejection) : value = null;

  Extracted<R> _map<R>(R Function(T) transform) {
    final rejection = this.rejection;
    if (rejection != null) return Extracted._(rejection);
    return Extracted.value(transform(value as T));
  }

  Extracted<T> _fillActual(Object? actual) => rejection == null ||
          rejection!.actual.isNotEmpty
      ? this
      : Extracted.rejection(actual: literal(actual), which: rejection!.which);
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

  final void Function(CheckFailure) _fail;

  final bool _allowAsync;
  final bool _allowUnawaited;

  /// A callback that returns a label for this context.
  ///
  /// If this context is the root the label should return a phrase like
  /// "a List" in
  ///
  /// ```
  /// Expected: a List that:
  /// ```
  ///
  /// If this context is nested under another context the lable should return a
  /// phrase like "completes to a value" in
  ///
  ///
  /// ```
  /// Expected: a Future<int> that:
  ///   completes to a value that:
  /// ```
  ///
  /// In cases where a nested context does not have any expectations checked on
  /// it, the "that:" will be will be omitted.
  final Iterable<String> Function() _label;

  static Iterable<String> _emptyLabel() => const [];

  /// Create a context appropriate for a subject which is not nested under any
  /// other subject.
  _TestContext._root({
    required _Optional<T> value,
    required void Function(CheckFailure) fail,
    required bool allowAsync,
    required bool allowUnawaited,
    String? label,
  })  : _value = value,
        _label = (() => [label ?? '']),
        _fail = fail,
        _allowAsync = allowAsync,
        _allowUnawaited = allowUnawaited,
        _parent = null,
        _clauses = [],
        _aliases = [];

  _TestContext._alias(_TestContext original, this._value)
      : _parent = original,
        _clauses = original._clauses,
        _aliases = original._aliases,
        _fail = original._fail,
        _allowAsync = original._allowAsync,
        _allowUnawaited = original._allowUnawaited,
        // Never read from an aliased context because they are never present in
        // `_clauses`.
        _label = _emptyLabel;

  /// Create a context nested under [parent].
  ///
  /// The [_label] callback should not return an empty iterable.
  _TestContext._child(this._value, this._label, _TestContext<dynamic> parent)
      : _parent = parent,
        _fail = parent._fail,
        _allowAsync = parent._allowAsync,
        _allowUnawaited = parent._allowUnawaited,
        _clauses = [],
        _aliases = [];

  @override
  void expect(
      Iterable<String> Function() clause, Rejection? Function(T) predicate) {
    _clauses.add(_ExpectationClause(clause));
    final rejection =
        _value.apply((actual) => predicate(actual)?._fillActual(actual));
    if (rejection != null) {
      _fail(_failure(rejection));
    }
  }

  @override
  Future<void> expectAsync<R>(Iterable<String> Function() clause,
      FutureOr<Rejection?> Function(T) predicate) async {
    if (!_allowAsync) {
      throw StateError(
          'Async expectations cannot be used on a synchronous subject');
    }
    _clauses.add(_ExpectationClause(clause));
    final outstandingWork = TestHandle.current.markPending();
    final rejection = await _value.apply(
        (actual) async => (await predicate(actual))?._fillActual(actual));
    outstandingWork.complete();
    if (rejection == null) return;
    _fail(_failure(rejection));
  }

  @override
  void expectUnawaited(Iterable<String> Function() clause,
      void Function(T actual, void Function(Rejection) reject) predicate) {
    if (!_allowUnawaited) {
      throw StateError('Late expectations cannot be used for soft checks');
    }
    _clauses.add(_ExpectationClause(clause));
    _value.apply((actual) {
      predicate(actual, (r) => _fail(_failure(r._fillActual(actual))));
    });
  }

  @override
  Subject<R> nest<R>(
      Iterable<String> Function() label, Extracted<R> Function(T) extract,
      {bool atSameLevel = false}) {
    final result = _value.map((actual) => extract(actual)._fillActual(actual));
    final rejection = result.rejection;
    if (rejection != null) {
      _clauses.add(_ExpectationClause(label));
      _fail(_failure(rejection));
    }
    final value = result.value ?? _Absent<R>();
    final _TestContext<R> context;
    if (atSameLevel) {
      context = _TestContext._alias(this, value);
      _aliases.add(context);
      _clauses.add(_ExpectationClause(label));
    } else {
      context = _TestContext._child(value, label, this);
      _clauses.add(context);
    }
    return Subject._(context);
  }

  @override
  Future<Subject<R>> nestAsync<R>(Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T) extract) async {
    if (!_allowAsync) {
      throw StateError(
          'Async expectations cannot be used on a synchronous subject');
    }
    final outstandingWork = TestHandle.current.markPending();
    final result = await _value.mapAsync(
        (actual) async => (await extract(actual))._fillActual(actual));
    outstandingWork.complete();
    final rejection = result.rejection;
    if (rejection != null) {
      _clauses.add(_ExpectationClause(label));
      _fail(_failure(rejection));
    }
    final value = result.value ?? _Absent<R>();
    final context = _TestContext<R>._child(value, label, this);
    _clauses.add(context);
    return Subject._(context);
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
    final thisContextFailed =
        identical(failingContext, this) || _aliases.contains(failingContext);
    var foundDepth = thisContextFailed ? 0 : -1;
    var foundOverlap = thisContextFailed ? 0 : -1;
    var successfulOverlap = 0;
    final expected = <String>[];
    if (_clauses.isEmpty) {
      expected.addAll(_label());
    } else {
      expected.addAll(postfixLast(' that:', _label()));
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
  void expectUnawaited(Iterable<String> Function() clause,
      void Function(T actual, void Function(Rejection) reject) predicate) {
    // no-op
  }

  @override
  Subject<R> nest<R>(
      Iterable<String> Function() label, Extracted<R> Function(T p1) extract,
      {bool atSameLevel = false}) {
    return Subject._(_SkippedContext());
  }

  @override
  Future<Subject<R>> nestAsync<R>(Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T p1) extract) async {
    return Subject._(_SkippedContext());
  }
}

abstract class _ClauseDescription {
  FailureDetail detail(_TestContext failingContext);
}

class _ExpectationClause implements _ClauseDescription {
  final Iterable<String> Function() _expected;
  _ExpectationClause(this._expected);
  @override
  FailureDetail detail(_TestContext failingContext) =>
      FailureDetail(_expected(), -1, -1);
}

/// The result an expectation that failed for a subject..
class CheckFailure {
  /// The specific rejected value within the overall subject that caused the
  /// failure.
  ///
  /// The [Rejection.actual] may be a property derived from the value at the
  /// root of the subject, for instance a field or an element in a collection.
  final Rejection rejection;

  /// The context within the overall subject where an expectation resulted in
  /// the [rejection].
  late final FailureDetail detail = _readDetail();

  final FailureDetail Function() _readDetail;

  CheckFailure(this.rejection, this._readDetail);
}

/// The context for a failed expectation.
///
/// A subject may have some number of succeeding expectations, and the failure may
/// be for an expectation against a property derived from the value at the root
/// of the subject. For example, in `check([]).length.equals(1)` the
/// specific value that gets rejected is `0` from the length of the list, and
/// the subject that sees the rejection is nested with the label "has length".
class FailureDetail {
  /// A description of all the conditions the subject was expected to satisfy.
  ///
  /// Each subject has a label. At the root the label is typically "a <Type>"
  /// and nested subjects get a label based on the condition which extracted a
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
  /// label for the subject that had a failing expectation. For example, if the
  /// equality check for the length of a list fails:
  ///
  ///   a List that:
  ///     has length that:
  ///
  /// If the subject with a failing expectation is the root, returns an empty
  /// list. Instead the "Actual: " value from the rejection can be used without
  /// indentation.
  Iterable<String> get actual =>
      _actualOverlap > 0 ? expected.take(_actualOverlap + 1) : const [];

  /// The number of lines from [expected] which describe conditions that were
  /// successful.
  ///
  /// A failed expectation on a derived property may have some number of
  /// expectations that were checked and satisfied starting from the root
  /// subject. This field indicates how many lines of expectations were
  /// successful.
  final int _actualOverlap;

  /// The number of times the failing subject was nested from the root subject.
  ///
  /// Indicates how far the "Actual: " and "Which: " lines from the [Rejection]
  /// should be indented so that they are at the same level of indentation as
  /// the label for the subject where the expectation failed.
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
  /// When a value is rejected with no [actual] argument, it will be filled in
  /// with the [literal] representation of the value.
  ///
  /// Lines should be split to separate elements, and individual strings should
  /// not contain newlines.
  ///
  /// This is printed following an "Actual: " label in the output of a failure
  /// message. All lines in the message will be indented to the level of the
  /// expectation in the description, and printed following the descriptions of
  /// any expectations that have already passed.
  final Iterable<String> actual;

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

  Rejection _fillActual(Object? value) => actual.isNotEmpty
      ? this
      : Rejection(actual: literal(value), which: which);

  Rejection({this.actual = const [], this.which});
}

class ConditionSubject<T> implements Subject<T>, Condition<T> {
  ConditionSubject._();

  @override
  void apply(Subject<T> subject) {
    _context.apply(subject);
  }

  @override
  Future<void> applyAsync(Subject<T> subject) async {
    await _context.applyAsync(subject);
  }

  @override
  final _ReplayContext<T> _context = _ReplayContext();

  @override
  String toString() {
    return ['A value that:', ...describe(_context)].join('\n');
  }
}

class _ReplayContext<T> implements Context<T>, Condition<T> {
  final _interactions = <FutureOr<void> Function(Context<T>)>[];

  @override
  void apply(Subject<T> subject) {
    for (var interaction in _interactions) {
      interaction(subject.context);
    }
  }

  @override
  Future<void> applyAsync(Subject<T> subject) async {
    for (var interaction in _interactions) {
      await interaction(subject.context);
    }
  }

  @override
  void expect(
      Iterable<String> Function() clause, Rejection? Function(T) predicate) {
    _interactions.add((c) {
      c.expect(clause, predicate);
    });
  }

  @override
  Future<void> expectAsync<R>(Iterable<String> Function() clause,
      FutureOr<Rejection?> Function(T) predicate) async {
    _interactions.add((c) async {
      await c.expectAsync(clause, predicate);
    });
  }

  @override
  void expectUnawaited(Iterable<String> Function() clause,
      void Function(T, void Function(Rejection)) predicate) {
    _interactions.add((c) {
      c.expectUnawaited(clause, predicate);
    });
  }

  @override
  Subject<R> nest<R>(
      Iterable<String> Function() label, Extracted<R> Function(T p1) extract,
      {bool atSameLevel = false}) {
    final nestedContext = _ReplayContext<R>();
    _interactions.add((c) {
      var result = c.nest(label, extract, atSameLevel: atSameLevel);
      nestedContext.apply(result);
    });
    return Subject._(nestedContext);
  }

  @override
  Future<Subject<R>> nestAsync<R>(Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T) extract) async {
    final nestedContext = _ReplayContext<R>();
    _interactions.add((c) async {
      var result = await c.nestAsync(label, extract);
      await nestedContext.applyAsync(result);
    });
    return Subject._(nestedContext);
  }
}
