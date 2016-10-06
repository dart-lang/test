// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): Get rid of this when https://codereview.chromium.org/1241723003/
// lands.
import 'dart:async';

import 'package:async/async.dart';

/// A single-subscription stream from which other streams may be forked off at
/// the current position.
///
/// This adds an operation, [fork], which produces a new stream that
/// independently emits the same events as this stream. Unlike the branches
/// produced by [StreamSplitter], a fork only emits events that arrive *after*
/// the call to [fork].
///
/// Each fork can be paused or canceled independently of one another and of this
/// stream. The underlying stream will be listened to once any branch is
/// listened to. It will be paused when all branches are paused or not yet
/// listened to. It will be canceled when all branches have been listened to and
/// then canceled.
class ForkableStream<T> extends StreamView<T> {
  /// The underlying stream.
  final Stream<T> _sourceStream;

  /// The subscription to [_sourceStream].
  ///
  /// This will be `null` until this stream or any of its forks are listened to.
  StreamSubscription _subscription;

  /// Whether this has been cancelled and no more forks may be created.
  bool _isCanceled = false;

  /// The controllers for any branches that have not yet been canceled.
  ///
  /// This includes a controller for this stream, until that has been cancelled.
  final _controllers = new Set<StreamController<T>>();

  /// Creates a new forkable stream wrapping [sourceStream].
  ForkableStream(Stream<T> sourceStream)
      // Use a completer here so that we can provide its stream to the
      // superclass constructor while also adding the stream controller to
      // [_controllers].
      : this._(sourceStream, new StreamCompleter<T>());

  ForkableStream._(this._sourceStream, StreamCompleter<T> completer)
      : super(completer.stream) {
    completer.setSourceStream(_fork(primary: true));
  }

  /// Creates a new fork of this stream.
  ///
  /// From this point forward, the fork will emit the same events as this
  /// stream. It will *not* emit any events that have already been emitted by
  /// this stream. The fork is independent of this stream, which means each one
  /// may be paused or canceled without affecting the other.
  ///
  /// If this stream is done or its subscription has been canceled, this returns
  /// an empty stream.
  Stream<T> fork() => _fork(primary: false);

  /// Creates a stream forwarding [_sourceStream].
  ///
  /// If [primary] is true, this is the stream underlying this object;
  /// otherwise, it's a fork. The only difference is that when the primary
  /// stream is canceled, [fork] starts throwing [StateError]s.
  Stream<T> _fork({bool primary: false}) {
    if (_isCanceled) {
      var controller = new StreamController<T>()..close();
      return controller.stream;
    }

    StreamController<T> controller;
    controller = new StreamController<T>(
        onListen: () => _onListenOrResume(controller),
        onCancel: () => _onCancel(controller, primary: primary),
        onPause: () => _onPause(controller),
        onResume: () => _onListenOrResume(controller),
        sync: true);

    _controllers.add(controller);

    return controller.stream;
  }

  /// The callback called when `onListen` or `onResume` is called for the branch
  /// managed by [controller].
  ///
  /// This ensures that we're subscribed to [_sourceStream] and that the
  /// subscription isn't paused.
  void _onListenOrResume(StreamController<T> controller) {
    if (controller.isClosed) return;
    if (_subscription == null) {
      _subscription =
          _sourceStream.listen(_onData, onError: _onError, onDone: _onDone);
    } else {
      _subscription.resume();
    }
  }

  /// The callback called when `onCancel` is called for the branch managed by
  /// [controller].
  ///
  /// This cancels or pauses the underlying subscription as necessary. If
  /// [primary] is true, it also ensures that future calls to [fork] throw
  /// [StateError]s.
  Future _onCancel(StreamController<T> controller, {bool primary: false}) {
    if (primary) _isCanceled = true;

    if (controller.isClosed) return null;
    _controllers.remove(controller);

    if (_controllers.isEmpty) return _subscription.cancel();

    _onPause(controller);
    return null;
  }

  /// The callback called when `onPause` is called for the branch managed by
  /// [controller].
  ///
  /// This pauses the underlying subscription if necessary.
  void _onPause(StreamController<T> controller) {
    if (controller.isClosed) return;
    if (_subscription.isPaused) return;
    if (_controllers.any((controller) =>
        controller.hasListener && !controller.isPaused)) {
      return;
    }

    _subscription.pause();
  }

  /// Forwards data events to all branches.
  void _onData(T value) {
    // Don't iterate directly over the set because [controller.add] might cause
    // it to be modified synchronously.
    for (var controller in _controllers.toList()) {
      controller.add(value);
    }
  }

  /// Forwards error events to all branches.
  void _onError(error, StackTrace stackTrace) {
    // Don't iterate directly over the set because [controller.addError] might
    // cause it to be modified synchronously.
    for (var controller in _controllers.toList()) {
      controller.addError(error, stackTrace);
    }
  }

  /// Forwards close events to all branches.
  void _onDone() {
    _isCanceled = true;

    // Don't iterate directly over the set because [controller.close] might
    // cause it to be modified synchronously.
    for (var controller in _controllers.toList()) {
      controller.close();
    }
    _controllers.clear();
  }
}

