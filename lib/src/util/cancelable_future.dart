// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): Use this from the async package when
// https://codereview.chromium.org/1266603005/ lands.
library test.util.cancelable_future;

import 'dart:async';

import 'package:async/async.dart';

/// A [Future] that can be cancelled.
///
/// When this is cancelled, that means it won't complete either successfully or
/// with an error.
///
/// In general it's a good idea to only have a single non-branching chain of
/// cancellable futures. If there are multiple branches, any of them that aren't
/// closed explicitly will throw a [CancelException] once one of them is
/// cancelled.
class CancelableFuture<T> implements Future<T> {
  /// The completer that produced this future.
  ///
  /// This is canceled when [cancel] is called.
  final CancelableCompleter<T> _completer;

  /// The future wrapped by [this].
  Future<T> _inner;

  /// Whether this future has been canceled.
  ///
  /// This is tracked individually for each future because a canceled future
  /// shouldn't emit events, but the completer will throw a [CancelException].
  bool _canceled = false;

  CancelableFuture._(this._completer, Future<T> inner) {
    // Once this future is canceled, it should never complete.
    _inner = inner.whenComplete(() {
      if (_canceled) return new Completer().future;
    });
  }

  /// Creates a [CancelableFuture] wrapping [inner].
  ///
  /// When this future is canceled, [onCancel] will be called. The callback may
  /// return a Future to indicate that asynchronous work has to be done to
  /// cancel the future; this Future will be returned by [cancel].
  factory CancelableFuture.fromFuture(Future<T> inner, [onCancel()]) {
    var completer = new CancelableCompleter<T>(onCancel);
    completer.complete(inner);
    return completer.future;
  }

  /// Creates a [Stream] containing the result of this future.
  ///
  /// If this Future is canceled, the Stream will not produce any events. If a
  /// subscription to the stream is canceled, this is as well.
  Stream<T> asStream() {
    var controller = new StreamController<T>(
        sync: true, onCancel: _completer._cancel);

    _inner.then((value) {
      controller.add(value);
      controller.close();
    }, onError: (error, stackTrace) {
      controller.addError(error, stackTrace);
      controller.close();
    });
    return controller.stream;
  }

  /// Returns [this] as a normal future.
  ///
  /// The returned future is different from this one in the following ways:
  ///
  /// * Its methods don't return [CancelableFuture]s.
  ///
  /// * It doesn't support [cancel] or [asFuture].
  ///
  /// * The [Stream] returned by [asStream] won't cancel the future if it's
  ///   canceled.
  ///
  /// * If a [timeout] times out, it won't cancel the future.
  Future asFuture() => _inner;

  CancelableFuture catchError(Function onError, {bool test(error)}) =>
      new CancelableFuture._(
          _completer, _inner.catchError(onError, test: test));

  CancelableFuture then(onValue(T value), {Function onError}) =>
      new CancelableFuture._(
          _completer, _inner.then(onValue, onError: onError));

  CancelableFuture<T> whenComplete(action()) =>
      new CancelableFuture<T>._(_completer, _inner.whenComplete(action));

  /// Time-out the future computation after [timeLimit] has passed.
  ///
  /// When the future times out, it will be canceled. Note that the return value
  /// of the completer's `onCancel` callback will be ignored by default, and any
  /// errors it produces silently dropped. To avoid this, call [cancel]
  /// explicitly in [onTimeout].
  CancelableFuture timeout(Duration timeLimit, {onTimeout()}) {
    var wrappedOnTimeout = () {
      // Ignore errors here because there's no good way to pipe them to the
      // caller without screwing up [onTimeout].
      _completer._cancel().catchError((_) {});
      if (onTimeout != null) return onTimeout();
      throw new TimeoutException("Future not completed", timeLimit);
    };

    return new CancelableFuture._(
        _completer, _inner.timeout(timeLimit, onTimeout: wrappedOnTimeout));
  }

  /// Cancels this future.
  ///
  /// This returns the [Future] returned by the [CancelableCompleter]'s
  /// `onCancel` callback. Unlike [Stream.cancel], it never returns `null`.
  Future cancel() {
    _canceled = true;
    return _completer._cancel();
  }
}

/// A completer for a [CancelableFuture].
class CancelableCompleter<T> implements Completer<T> {
  /// The completer for the wrapped future.
  final Completer<T> _inner;

  /// The callback to call if the future is canceled.
  final ZoneCallback _onCancel;

  CancelableFuture<T> get future => _future;
  CancelableFuture<T> _future;

  bool get isCompleted => _isCompleted;
  bool _isCompleted = false;

  /// Whether the completer was canceled before being completed.
  bool get isCanceled => _isCanceled;
  bool _isCanceled = false;

  /// Whether the completer has fired.
  ///
  /// This is distinct from [isCompleted] when a [Future] is passed to
  /// [complete]; this won't be `true` until that [Future] fires.
  bool _fired = false;

  /// Creates a new completer for a [CancelableFuture].
  ///
  /// When the future is canceled, as long as the completer hasn't yet
  /// completed, [onCancel] is called. The callback may return a [Future]; if
  /// so, that [Future] is returned by [CancelableFuture.cancel].
  CancelableCompleter([this._onCancel])
      : _inner = new Completer<T>() {
    _future = new CancelableFuture<T>._(this, _inner.future);
  }

  void complete([value]) {
    if (_isCompleted) throw new StateError("Future already completed");
    _isCompleted = true;

    if (_isCanceled) return;
    if (value is! Future) {
      _fired = true;
      _inner.complete(value);
      return;
    }

    value.then((result) {
      if (_isCanceled) return;
      _fired = true;
      _inner.complete(result);
    }, onError: (error, stackTrace) {
      if (_isCanceled) return;
      _fired = true;
      _inner.completeError(error, stackTrace);
    });
  }

  void completeError(Object error, [StackTrace stackTrace]) {
    if (_isCompleted) throw new StateError("Future already completed");
    _isCompleted = true;

    if (_isCanceled) return;
    _fired = true;
    _inner.completeError(error, stackTrace);
  }

  /// Cancel the completer.
  Future _cancel() => _cancelMemo.runOnce(() {
    if (_fired) return null;
    _isCanceled = true;

    // Throw an catch to get access to the current stack trace.
    try {
      throw new CancelException();
    } catch (error, stackTrace) {
      _inner.completeError(error, stackTrace);
    }

    if (_onCancel != null) return _onCancel();
  });
  final _cancelMemo = new AsyncMemoizer();
}

/// An exception thrown when a [CancelableFuture] is canceled.
///
/// Since a canceled [CancelableFuture] doesn't receive any more events, this
/// will only be passed to other branches of the future chain.
class CancelException implements Exception {
  CancelException();

  String toString() => "This Future has been canceled.";
}
