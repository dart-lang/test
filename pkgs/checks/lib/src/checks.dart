// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart' as meta;
import 'package:test_api/hooks.dart';

import 'describe.dart';
import 'extensions/async.dart';
import 'extensions/core.dart';
import 'extensions/iterable.dart';

/// A target for checking expectations against a value in a test.
///
/// A subject my have a real value, in which case the expectations can be
/// validated or rejected; or it may be a placeholder, in which case
/// expectations describe what would be checked but cannot be rejected.
///
/// Expectation methods are defined in extensions `on Subject`, specialized on
/// the generic [T].
/// Expectation extension methods can use the [ContextExtension] to interact
/// with the [Context] for this subject.
///
/// Create a subject that throws an exception for missed expectations with the
/// [check] function.
///
/// Create a subject which records expectations and can be replayed as a
/// [Condition] with the [it] function.
final class Subject<T> {
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
      failure ??= f;
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
      failure ??= f;
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
abstract interface class Condition<T> {
  /// Check the expectations of this condition against [subject].
  ///
  /// The [subject] should throw if any asynchronous expectations are checked.
  /// It is not possible to wait for for asynchronous expectations to be fully
  /// applied with this method.
  void apply(Subject<T> subject);

  /// Check the expectations of this condition against [subject].
  Future<void> applyAsync(Subject<T> subject);
}

ConditionSubject<T> it<T>() => ConditionSubject._();

extension ContextExtension<T> on Subject<T> {
  /// The expectations and nesting context for this subject.
  Context<T> get context => _context;
}

/// The context for a [Subject] that allows asserting expectations and creating
/// nested subjects.
///
/// A [Subject] is the target for checking expectations in a test.
/// Every subject has a [Context] which holds the "actual" value, tracks how the
/// value was obtained, and can check expectations about the value.
///
/// The user focused APIs called within tests are expectation extension methods
/// written in an extension `on Subject`, typically specialized to a specific
/// generic.
///
/// Expectation extension methods will make a call to one of the APIs on the
/// subject's [Context], and can perform one of two types of operations:
///
/// -   Expect something of the current value (such as [CoreChecks.equals] or
///     [IterableChecks.contains]) by calling [expect], [expectAsync], or
///     [expectUnawaited].
/// -   Expect that a new subject can be extracted from the current value (such
///     as [CoreChecks.has] or [FutureChecks.completes]) by calling [nest] or
///     [nestAsync].
///
///
/// Whichever type of operation, an expectation extension method provides two
/// callbacks.
/// The first callback is an `Iterable<String> Function()` returning a
/// description of the expectation.
/// The second callback always takes the actual value as an argument, and the
/// specific signature varies by operation.
///
///
/// In expectation extension methods calling [expect], [expectAync], or
/// [expectUnawaited], the `predicate` callback can report a [Rejection] if the
/// value fails to satisfy the expectation.
/// The description will be passed in a "clause" callback.
/// {@template clause_description}
/// The clause callback returns a description of what is checked which stands
/// on its own.
/// For instance the `is equal to <1>` in:
///
/// ```
/// Expected: a int that:
///   is equal to <1>
/// ```
/// {@endtemplate}
///
///
/// In expectation extension methods calling [nest] or [nestAsync], the
/// `extract` callback can return a [Extracted.rejection] if the value fails to
/// satisfy an expectation which disallows extracting the value, or an
/// [Extracted.value] to become the value in a nested subject.
/// The description will be passed in a "label" callback.
/// {@template label_description}
/// The label callback returns a description of the extracted subject as it
/// relates to the original subject.
/// For instance the `completes to a value` in:
///
/// ```
/// Expected a Future<int> that:
///   completes to a value that:
///     is equal to <1>
/// ```
///
/// A label should also be sensible when it is read as a clause.
/// If no further expectations are checked on the extracted subject, or if the
/// extraction is rejected, the "that:" is omitted in the output.
///
/// ```
///   Expected a Future<int> that:
///     completes to a value
/// ```
/// {@endtemplate}
///
///
/// A rejection carries two descriptions, one description of the "actual" value
/// that was tested, and an optional "which" with further details about how the
/// result different from the expectation.
/// If the "actual" argument is omitted it will be filled with a representation
/// of the value passed to the expectation callback formatted with [literal].
/// If an expectation extension method is written on a type of subject without a
/// useful `toString()`, the rejection can provide a string representation to
/// use instead.
/// The "which" argument may be omitted if the reason is very obvious based on
/// the clause and "actual" description, but most expectations should include a
/// "which".
///
/// The behavior of a context following a rejection depends on the source of the
/// [Subject].
///
/// When an expectation is rejected for a [check] subject, an exception is
/// thrown to interrupt the test, so no further checks should happen. The
/// failure message will include:
/// -  An "Expected" section with descriptions of all the expectations that
///    were checked, including the ones that passed, and the last one that
///    failed.
/// -  An "Actual" section, which may be the description directly from the
///    [Rejection] if the failure was on the root subject, or may start with a
///    partial version of the "Expected" description up to the label for the
///    nesting subject that saw a failure, then the "actual" from the rejection.
/// -  A "Which" description from the rejection, if it was included.
///
/// For example, if a failure happens on the root subject, the "actual" is taken
/// directly from the rejection.
///
/// ```
/// Expected: a Future<int> that:
///   completes to a value
/// Actual: a future that completes as an error
/// Which: threw <UnimplementedError> at:
/// <stack trace>
/// ```
///
/// But if the failure happens on a nested subject, the actual starts with a
/// description of the nesting or non-nesting expectations that succeeded, up
/// to nesting point of the failure, then the "actual" and "which" from the
/// rejection are indented to that level of nesting.
///
/// ```
/// Expected: a Future<int> that:
///   completes to a value that:
///     equals <1>
/// Actual: a Future<int> that:
///   completes to a value that:
///   Actual: <0>
///   Which: are not equal
/// ```
///
/// ```dart
/// extension CustomChecks on Subject<CustomType> {
///   void someExpectation() {
///     context.expect(() => ['meets this expectation'], (actual) {
///       if (_expectationIsMet(actual)) return null;
///       return Rejection(which: ['does not meet this expectation']);
///     });
///   }
///
///   Subject<Foo> get someDerivedValue =>
///       context.nest('has someDerivedValue', (actual) {
///         if (_cannotReadDerivedValue(actual)) {
///           return Extracted.rejection(which: ['cannot read someDerivedValue']);
///         }
///         return Extracted.value(_readDerivedValue(actual));
///       });
///
///   // for field reads that will not get rejected, use `has`
///   Subject<Bar> get someField => has((a) => a.someField, 'someField');
/// }
/// ```
///
/// When an expectation is rejected for a subject within a call to [softCheck]
/// or [softCheckAsync] a [CheckFailure] will be returned with the rejection, as
/// well as a [FailureDetail] which could be used to format the same failure
/// message thrown by the [check] subject.
///
/// {@template callbacks_may_be_unused}
/// The description of an expectation may never be shown to the user, so the
/// callback may never be invoked.
/// If all the conditions on a subject succeed, or if the failure detail for a
/// failed [softCheck] is never read, the descriptions will be unused.
/// String formatting for the descriptions should be performed in the callback,
/// not ahead of time.
///
///
/// The context for a subject may hold a real "actual" value to test against, or
/// it may have a placeholder within a call to [describe].
/// A context with a placeholder value will not invoke the callback to check
/// expectations.
///
/// If both callbacks are invoked, the description callback will always be
/// called strictly after the expectation callback is called.
///
/// Callbacks passed to a context should not throw.
/// {@endtemplate}
///
///
/// Some contexts disallow certain interactions.
/// {@template async_limitations}
/// Calls to [expectAsync] or [nestAsync] must not be performed by a [Condition]
/// passed to [softCheck] or [describe].
/// Use [softCheckAsync] or [describeAsync] for any condition which checks async
/// expectations.
/// {@endtemplate}
/// {@template unawaited_limitations}
/// Calls to [expectUnawaited] may not be performed by a [Condition] passed to
/// [softCheck] or [softCheckAsync].
/// {@endtemplate}
///
/// Expectation extension methods can access the context for the subject with
/// the [ContextExtension].
///
/// The [it] utility returns a subject whose context will not directly invoke
/// any callbacks, but stores them and passed them along  when the
/// [ConditionSubject] is replayed as a [Condition] against another subject.
///
/// {@template description_lines}
/// Description callbacks return an `Iterable<String>` where each element is a
/// line in the output. Individual elements should not contain newlines.
/// Utilities such as [prefixFirst], [postfixLast], and [literal] may be useful
/// to format values which are potentially multiline.
/// {@endtemplate}
abstract final class Context<T> {
  /// Expect that [predicate] will not return a [Rejection] for the checked
  /// value.
  ///
  /// {@macro clause_description}
  ///
  /// {@macro description_lines}
  ///
  /// {@macro callbacks_may_be_unused}
  ///
  /// ```dart
  /// void someExpectation() {
  ///   context.expect(() => ['meets this expectation'], (actual) {
  ///     if (_expectationIsMet(actual)) return null;
  ///     return Rejection(which: ['does not meet this expectation']);
  ///   });
  /// }
  /// ```
  void expect(
      Iterable<String> Function() clause, Rejection? Function(T) predicate);

  /// Expect that [predicate] will not result in a [Rejection] for the checked
  /// value.
  ///
  /// {@macro clause_description}
  ///
  /// {@macro description_lines}
  ///
  /// {@macro callbacks_may_be_unused}
  ///
  /// {@macro async_limitations}
  ///
  /// ```dart
  /// extension CustomChecks on Subject<CustomType> {
  ///   Future<void> someAsyncExpectation() async {
  ///     await context.expectAsync(() => ['meets this async expectation'],
  ///         (actual) async {
  ///       if (await _expectationIsMet(actual)) return null;
  ///       return Rejection(which: ['does not meet this async expectation']);
  ///     });
  ///   }
  /// }
  /// ```
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
  /// {@macro clause_description}
  ///
  /// {@macro description_lines}
  ///
  /// {@macro callbacks_may_be_unused}
  ///
  /// {@macro unawaited_limitations}
  /// The only useful effect of a late rejection is to throw a [TestFailure]
  /// when used with a [check] subject. Most conditions should prefer to use
  /// [expect] or [expectAsync].
  ///
  /// ```dart
  /// void someUnawaitableExpectation() async {
  ///   await context.expectUnawaited(
  ///       () => ['meets this unawaitable expectation'], (actual, reject) {
  ///     final failureSignal = _completeIfFailed(actual);
  ///     unawaited(failureSignal.then((_) {
  ///       reject(Reject(
  ///           which: ['unexpectedly failed this unawaited expectation']));
  ///     }));
  ///   });
  /// }
  /// ```
  void expectUnawaited(Iterable<String> Function() clause,
      void Function(T, void Function(Rejection)) predicate);

  /// Extract a property from the value for further checking.
  ///
  /// If the property cannot be extracted, [extract] should return an
  /// [Extracted.rejection] describing the problem. Otherwise it should return
  /// an [Extracted.value].
  ///
  /// Subsequent expectations can be checked for the extracted value on the
  /// returned [Subject].
  ///
  /// {@macro label_description}
  ///
  /// If [atSameLevel] is true then the returned [Extracted.value] should hold
  /// the same instance as the passed value, or an object which is is equivalent
  /// but has a type that is more convenient to test.
  /// In this case expectations applied to the returned [Subject] will behave as
  /// if they were applied to the subject for this context.
  /// The [label] will be used as if it were a "clause" argument passed to
  /// [expect].
  /// If the label returns an empty iterable, the clause will be omitted.
  /// The label should only be left empty if the value extraction cannot be
  /// rejected.
  ///
  /// {@macro description_lines}
  ///
  /// {@macro callbacks_may_be_unused}
  ///
  /// ```dart
  /// Subject<Foo> get someDerivedValue =>
  ///     context.nest(() => ['has someDerivedValue'], (actual) {
  ///       if (_cannotReadDerivedValue(actual)) {
  ///         return Extracted.rejection(
  ///             which: ['cannot read someDerivedValue']);
  ///       }
  ///       return Extracted.value(_readDerivedValue(actual));
  ///     });
  /// ```
  void nest<R>(Iterable<String> Function() label,
      Extracted<R> Function(T) extract, Condition<R>? nestedCondition,
      {bool atSameLevel = false});

  /// Extract an asynchronous property from the value for further checking.
  ///
  /// If the property cannot be extracted, [extract] should return an
  /// [Extracted.rejection] describing the problem. Otherwise it should return
  /// an [Extracted.value].
  ///
  /// In contrast to [nest], subsequent expectations need to be passed in
  /// [nestedCondition] which will be applied to the subject for the extracted
  /// value.
  ///
  /// {@macro label_description}
  ///
  /// {@macro description_lines}
  ///
  /// {@macro callbacks_may_be_unused}
  ///
  /// {@macro async_limitations}
  ///
  /// ```dart
  /// Future<void> someAsyncResult([Condition<Result> resultCondition]) async {
  ///   await context.nestAsync(() => ['has someAsyncResult'], (actual) async {
  ///     if (await _asyncOperationFailed(actual)) {
  ///       return Extracted.rejection(which: ['cannot read someAsyncResult']);
  ///     }
  ///     return Extracted.value(await _readAsyncResult(actual));
  ///   }, resultCondition);
  /// }
  /// ```
  Future<void> nestAsync<R>(
      Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T) extract,
      Condition<R>? nestedCondition);
}

/// A property extracted from a value being checked, or a rejection.
final class Extracted<T> {
  final Rejection? _rejection;
  final T? _value;

  /// Creates a rejected extraction to indicate a failure trying to read the
  /// value.
  ///
  /// When a nesting is rejected with an omitted or empty [actual] argument, it
  /// will be filled in with the [literal] representation of the value.
  Extracted.rejection(
      {Iterable<String> actual = const [], Iterable<String>? which})
      : _rejection = Rejection(actual: actual, which: which),
        _value = null;
  Extracted.value(T this._value) : _rejection = null;

  Extracted._(Rejection this._rejection) : _value = null;

  Extracted<R> _map<R>(R Function(T) transform) {
    final rejection = _rejection;
    if (rejection != null) return Extracted._(rejection);
    return Extracted.value(transform(_value as T));
  }

  Extracted<T> _fillActual(Object? actual) => _rejection == null ||
          _rejection!.actual.isNotEmpty
      ? this
      : Extracted.rejection(actual: literal(actual), which: _rejection!.which);
}

abstract interface class _Optional<T> {
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

final class _TestContext<T> implements Context<T>, _ClauseDescription {
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
    try {
      final rejection = await _value.apply(
          (actual) async => (await predicate(actual))?._fillActual(actual));
      if (rejection == null) return;
      _fail(_failure(rejection));
    } finally {
      outstandingWork.complete();
    }
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
  void nest<R>(Iterable<String> Function() label,
      Extracted<R> Function(T) extract, Condition<R>? nestedCondition,
      {bool atSameLevel = false}) {
    final result = _value.map((actual) => extract(actual)._fillActual(actual));
    final rejection = result._rejection;
    if (rejection != null) {
      _clauses.add(_ExpectationClause(label));
      _fail(_failure(rejection));
    }
    final value = result._value ?? _Absent<R>();
    final _TestContext<R> context;
    if (atSameLevel) {
      context = _TestContext._alias(this, value);
      _aliases.add(context);
      _clauses.add(_ExpectationClause(label));
    } else {
      context = _TestContext._child(value, label, this);
      _clauses.add(context);
    }
    nestedCondition?.apply(Subject<R>._(context));
  }

  @override
  Future<void> nestAsync<R>(
      Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T) extract,
      Condition<R>? nestedCondition) async {
    if (!_allowAsync) {
      throw StateError(
          'Async expectations cannot be used on a synchronous subject');
    }
    final outstandingWork = TestHandle.current.markPending();
    try {
      final result = await _value.mapAsync(
          (actual) async => (await extract(actual))._fillActual(actual));
      final rejection = result._rejection;
      if (rejection != null) {
        _clauses.add(_ExpectationClause(label));
        _fail(_failure(rejection));
      }
      final value = result._value ?? _Absent<R>();
      final context = _TestContext<R>._child(value, label, this);
      _clauses.add(context);
      await nestedCondition?.applyAsync(Subject<R>._(context));
    } finally {
      outstandingWork.complete();
    }
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
final class _SkippedContext<T> implements Context<T> {
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
  void nest<R>(Iterable<String> Function() label,
      Extracted<R> Function(T p1) extract, Condition<R>? nestedCondition,
      {bool atSameLevel = false}) {
    // no-op
  }

  @override
  Future<void> nestAsync<R>(
      Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T p1) extract,
      Condition<R>? nestedCondition) async {
    // no-op
  }
}

abstract interface class _ClauseDescription {
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
final class CheckFailure {
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
final class FailureDetail {
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
final class Rejection {
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

/// A [Subject] which records expectations and can replay them as a [Condition].
final class ConditionSubject<T> implements Subject<T>, Condition<T> {
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

final class _ReplayContext<T> implements Context<T>, Condition<T> {
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
  void nest<R>(Iterable<String> Function() label,
      Extracted<R> Function(T p1) extract, Condition<R>? nestedCondition,
      {bool atSameLevel = false}) {
    _interactions.add((c) {
      c.nest(label, extract, nestedCondition, atSameLevel: atSameLevel);
    });
  }

  @override
  Future<void> nestAsync<R>(
      Iterable<String> Function() label,
      FutureOr<Extracted<R>> Function(T) extract,
      Condition<R>? nestedCondition) async {
    _interactions.add((c) async {
      await c.nestAsync(label, extract, nestedCondition);
    });
  }
}
