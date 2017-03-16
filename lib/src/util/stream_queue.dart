// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): Get rid of this when https://codereview.chromium.org/1241723003/
// lands.
import 'dart:async';
import 'dart:collection';

import "package:async/async.dart" hide ForkableStream, StreamQueue;

import "forkable_stream.dart";

/// An asynchronous pull-based interface for accessing stream events.
///
/// Wraps a stream and makes individual events available on request.
///
/// You can request (and reserve) one or more events from the stream,
/// and after all previous requests have been fulfilled, stream events
/// go towards fulfilling your request.
///
/// For example, if you ask for [next] two times, the returned futures
/// will be completed by the next two unrequested events from the stream.
///
/// The stream subscription is paused when there are no active
/// requests.
///
/// Some streams, including broadcast streams, will buffer
/// events while paused, so waiting too long between requests may
/// cause memory bloat somewhere else.
///
/// This is similar to, but more convenient than, a [StreamIterator].
/// A `StreamIterator` requires you to manually check when a new event is
/// available and you can only access the value of that event until you
/// check for the next one. A `StreamQueue` allows you to request, for example,
/// three events at a time, either individually, as a group using [take]
/// or [skip], or in any combination.
///
/// You can also ask to have the [rest] of the stream provided as
/// a new stream. This allows, for example, taking the first event
/// out of a stream and continuing to use the rest of the stream as a stream.
///
/// Example:
///
///     var events = new StreamQueue<String>(someStreamOfLines);
///     var first = await events.next;
///     while (first.startsWith('#')) {
///       // Skip comments.
///       first = await events.next;
///     }
///
///     if (first.startsWith(MAGIC_MARKER)) {
///       var headerCount =
///           first.parseInt(first.substring(MAGIC_MARKER.length + 1));
///       handleMessage(headers: await events.take(headerCount),
///                     body: events.rest);
///       return;
///     }
///     // Error handling.
///
/// When you need no further events the `StreamQueue` should be closed
/// using [cancel]. This releases the underlying stream subscription.
class StreamQueue<T> {
  // This class maintains two queues: one of events and one of requests.
  // The active request (the one in front of the queue) is called with
  // the current event queue when it becomes active.
  //
  // If the request returns true, it's complete and will be removed from the
  // request queue.
  // If the request returns false, it needs more events, and will be called
  // again when new events are available.
  // The request can remove events that it uses, or keep them in the event
  // queue until it has all that it needs.
  //
  // This model is very flexible and easily extensible.
  // It allows requests that don't consume events (like [hasNext]) or
  // potentially a request that takes either five or zero events, determined
  // by the content of the fifth event.

  /// Source of events.
  final ForkableStream<T> _sourceStream;

  /// Subscription on [_sourceStream] while listening for events.
  ///
  /// Set to subscription when listening, and set to `null` when the
  /// subscription is done (and [_isDone] is set to true).
  StreamSubscription<T> _subscription;

  /// Whether we have listened on [_sourceStream] and the subscription is done.
  bool _isDone = false;

  /// Whether a closing operation has been performed on the stream queue.
  ///
  /// Closing operations are [cancel] and [rest].
  bool _isClosed = false;

  /// Queue of events not used by a request yet.
  final Queue<Result> _eventQueue = new Queue();

  /// Queue of pending requests.
  ///
  /// Access through methods below to ensure consistency.
  final Queue<_EventRequest> _requestQueue = new Queue();

  /// Create a `StreamQueue` of the events of [source].
  StreamQueue(Stream<T> source)
      : _sourceStream = source is ForkableStream
          ? source
          : new ForkableStream(source);

  /// Asks if the stream has any more events.
  ///
  /// Returns a future that completes with `true` if the stream has any
  /// more events, whether data or error.
  /// If the stream closes without producing any more events, the returned
  /// future completes with `false`.
  ///
  /// Can be used before using [next] to avoid getting an error in the
  /// future returned by `next` in the case where there are no more events.
  Future<bool> get hasNext {
    if (!_isClosed) {
      var hasNextRequest = new _HasNextRequest();
      _addRequest(hasNextRequest);
      return hasNextRequest.future;
    }
    throw _failClosed();
  }

  /// Requests the next (yet unrequested) event from the stream.
  ///
  /// When the requested event arrives, the returned future is completed with
  /// the event.
  /// If the event is a data event, the returned future completes
  /// with its value.
  /// If the event is an error event, the returned future completes with
  /// its error and stack trace.
  /// If the stream closes before an event arrives, the returned future
  /// completes with a [StateError].
  ///
  /// It's possible to have several pending [next] calls (or other requests),
  /// and they will be completed in the order they were requested, by the
  /// first events that were not consumed by previous requeusts.
  Future<T> get next {
    if (!_isClosed) {
      var nextRequest = new _NextRequest<T>();
      _addRequest(nextRequest);
      return nextRequest.future;
    }
    throw _failClosed();
  }

  /// Returns a stream of all the remaning events of the source stream.
  ///
  /// All requested [next], [skip] or [take] operations are completed
  /// first, and then any remaining events are provided as events of
  /// the returned stream.
  ///
  /// Using `rest` closes this stream queue. After getting the
  /// `rest` the caller may no longer request other events, like
  /// after calling [cancel].
  Stream<T> get rest {
    if (_isClosed) {
      throw _failClosed();
    }
    var request = new _RestRequest<T>(this);
    _isClosed = true;
    _addRequest(request);
    return request.stream;
  }

  /// Skips the next [count] *data* events.
  ///
  /// The [count] must be non-negative.
  ///
  /// When successful, this is equivalent to using [take]
  /// and ignoring the result.
  ///
  /// If an error occurs before `count` data events have been skipped,
  /// the returned future completes with that error instead.
  ///
  /// If the stream closes before `count` data events,
  /// the remaining unskipped event count is returned.
  /// If the returned future completes with the integer `0`,
  /// then all events were succssfully skipped. If the value
  /// is greater than zero then the stream ended early.
  Future<int> skip(int count) {
    if (count < 0) throw new RangeError.range(count, 0, null, "count");
    if (!_isClosed) {
      var request = new _SkipRequest(count);
      _addRequest(request);
      return request.future;
    }
    throw _failClosed();
  }

  /// Requests the next [count] data events as a list.
  ///
  /// The [count] must be non-negative.
  ///
  /// Equivalent to calling [next] `count` times and
  /// storing the data values in a list.
  ///
  /// If an error occurs before `count` data events has
  /// been collected, the returned future completes with
  /// that error instead.
  ///
  /// If the stream closes before `count` data events,
  /// the returned future completes with the list
  /// of data collected so far. That is, the returned
  /// list may have fewer than [count] elements.
  Future<List<T>> take(int count) {
    if (count < 0) throw new RangeError.range(count, 0, null, "count");
    if (!_isClosed) {
      var request = new _TakeRequest<T>(count);
      _addRequest(request);
      return request.future;
    }
    throw _failClosed();
  }

  /// Creates a new stream queue in the same position as this one.
  ///
  /// The fork is subscribed to the same underlying stream as this queue, but
  /// it's otherwise wholly independent. If requests are made on one, they don't
  /// move the other forward; if one is closed, the other is still open.
  ///
  /// The underlying stream will only be paused when all forks have no
  /// outstanding requests, and only canceled when all forks are canceled.
  StreamQueue<T> fork() {
    if (_isClosed) throw _failClosed();

    var request = new _ForkRequest<T>(this);
    _addRequest(request);
    return request.queue;
  }

  /// Cancels the underlying stream subscription.
  ///
  /// If [immediate] is `false` (the default), the cancel operation waits until
  /// all previously requested events have been processed, then it cancels the
  /// subscription providing the events.
  ///
  /// If [immediate] is `true`, the subscription is instead canceled
  /// immediately. Any pending events complete with a 'closed'-event, as though
  /// the stream had closed by itself.
  ///
  /// The returned future completes with the result of calling
  /// `cancel`.
  ///
  /// After calling `cancel`, no further events can be requested.
  /// None of [next], [rest], [skip], [take] or [cancel] may be
  /// called again.
  Future cancel({bool immediate: false}) {
    if (_isClosed) throw _failClosed();
    _isClosed = true;

    if (_isDone) return new Future.value();
    if (_subscription == null) _subscription = _sourceStream.listen(null);

    if (!immediate) {
      var request = new _CancelRequest(this);
      _addRequest(request);
      return request.future;
    }

    var future = _subscription.cancel();
    _onDone();
    return future;
  }

  /// Returns an error for when a request is made after cancel.
  ///
  /// Returns a [StateError] with a message saying that either
  /// [cancel] or [rest] have already been called.
  Error _failClosed() {
    return new StateError("Already cancelled");
  }

  // Callbacks receiving the events of the source stream.

  void _onData(T data) {
    _eventQueue.add(new Result.value(data));
    _checkQueues();
  }

  void _onError(error, StackTrace stack) {
    _eventQueue.add(new Result.error(error, stack));
    _checkQueues();
  }

  void _onDone() {
    _subscription = null;
    _isDone = true;
    _closeAllRequests();
  }

  // Request queue management.

  /// Adds a new request to the queue.
  void _addRequest(_EventRequest request) {
    if (_isDone) {
      assert(_requestQueue.isEmpty);
      if (!request.addEvents(_eventQueue)) {
        request.close(_eventQueue);
      }
      return;
    }
    if (_requestQueue.isEmpty) {
      if (request.addEvents(_eventQueue)) return;
      _ensureListening();
    }
    _requestQueue.add(request);
  }

  /// Ensures that we are listening on events from [_sourceStream].
  ///
  /// Resumes subscription on [_sourceStream], or creates it if necessary.
  void _ensureListening() {
    assert(!_isDone);
    if (_subscription == null) {
      _subscription =
          _sourceStream.listen(_onData, onError: _onError, onDone: _onDone);
    } else {
      _subscription.resume();
    }
  }

  /// Removes all requests and closes them.
  ///
  /// Used when the source stream is done.
  /// After this, no further requests will be added to the queue,
  /// requests are immediately served entirely by events already in the event
  /// queue, if any.
  void _closeAllRequests() {
    assert(_isDone);
    while (_requestQueue.isNotEmpty) {
      var request = _requestQueue.removeFirst();
      if (!request.addEvents(_eventQueue)) {
        request.close(_eventQueue);
      }
    }
  }

  /// Matches events with requests.
  ///
  /// Called after receiving an event.
  void _checkQueues() {
    while (_requestQueue.isNotEmpty) {
      if (_requestQueue.first.addEvents(_eventQueue)) {
        _requestQueue.removeFirst();
      } else {
        return;
      }
    }

    if (!_isDone) {
      _subscription.pause();
    }
  }

  /// Extracts the subscription and makes this stream queue unusable.
  ///
  /// Can only be used by the very last request.
  StreamSubscription<T> _dispose() {
    assert(_isClosed);
    var subscription = _subscription;
    _subscription = null;
    _isDone = true;
    return subscription;
  }
}

/// Request object that receives events when they arrive, until fulfilled.
///
/// Each request that cannot be fulfilled immediately is represented by
/// an `_EventRequest` object in the request queue.
///
/// Events from the source stream are sent to the first request in the
/// queue until it reports itself as [isComplete].
///
/// When the first request in the queue `isComplete`, either when becoming
/// the first request or after receiving an event, its [close] methods is
/// called.
///
/// The [close] method is also called immediately when the source stream
/// is done.
abstract class _EventRequest {
  /// Handle available events.
  ///
  /// The available events are provided as a queue. The `addEvents` function
  /// should only remove events from the front of the event queue, e.g.,
  /// using [removeFirst].
  ///
  /// Returns `true` if the request is completed, or `false` if it needs
  /// more events.
  /// The call may keep events in the queue until the requeust is complete,
  /// or it may remove them immediately.
  ///
  /// If the method returns true, the request is considered fulfilled, and
  /// will never be called again.
  ///
  /// This method is called when a request reaches the front of the request
  /// queue, and if it returns `false`, it's called again every time a new event
  /// becomes available, or when the stream closes.
  bool addEvents(Queue<Result> events);

  /// Complete the request.
  ///
  /// This is called when the source stream is done before the request
  /// had a chance to receive all its events. That is, after a call
  /// to [addEvents] has returned `false`.
  /// If there are any unused events available, they are in the [events] queue.
  /// No further events will become available.
  ///
  /// The queue should only remove events from the front of the event queue,
  /// e.g., using [removeFirst].
  ///
  /// If the request kept events in the queue after an [addEvents] call,
  /// this is the last chance to use them.
  void close(Queue<Result> events);
}

/// Request for a [StreamQueue.next] call.
///
/// Completes the returned future when receiving the first event,
/// and is then complete.
class _NextRequest<T> implements _EventRequest {
  /// Completer for the future returned by [StreamQueue.next].
  final _completer = new Completer<T>();

  _NextRequest();

  Future<T> get future => _completer.future;

  bool addEvents(Queue<Result> events) {
    if (events.isEmpty) return false;
    events.removeFirst().complete(_completer);
    return true;
  }

  void close(Queue<Result> events) {
    var errorFuture =
        new Future<T>.sync(() => throw new StateError("No elements"));
    _completer.complete(errorFuture);
  }
}

/// Request for a [StreamQueue.skip] call.
class _SkipRequest implements _EventRequest {
  /// Completer for the future returned by the skip call.
  final _completer = new Completer<int>();

  /// Number of remaining events to skip.
  ///
  /// The request [isComplete] when the values reaches zero.
  ///
  /// Decremented when an event is seen.
  /// Set to zero when an error is seen since errors abort the skip request.
  int _eventsToSkip;

  _SkipRequest(this._eventsToSkip);

  /// The future completed when the correct number of events have been skipped.
  Future<int> get future => _completer.future;

  bool addEvents(Queue<Result> events) {
    while (_eventsToSkip > 0) {
      if (events.isEmpty) return false;
      _eventsToSkip--;
      var event = events.removeFirst();
      if (event.isError) {
        event.complete(_completer);
        return true;
      }
    }
    _completer.complete(0);
    return true;
  }

  void close(Queue<Result> events) {
    _completer.complete(_eventsToSkip);
  }
}

/// Request for a [StreamQueue.take] call.
class _TakeRequest<T> implements _EventRequest {
  /// Completer for the future returned by the take call.
  final _completer = new Completer<List<T>>();

  /// List collecting events until enough have been seen.
  final _list = <T>[];

  /// Number of events to capture.
  ///
  /// The request [isComplete] when the length of [_list] reaches
  /// this value.
  final int _eventsToTake;

  _TakeRequest(this._eventsToTake);

  /// The future completed when the correct number of events have been captured.
  Future<List<T>> get future => _completer.future;

  bool addEvents(Queue<Result> events) {
    while (_list.length < _eventsToTake) {
      if (events.isEmpty) return false;
      var result = events.removeFirst();
      if (result.isError) {
        result.complete(_completer);
        return true;
      }
      _list.add(result.asValue.value);
    }
    _completer.complete(_list);
    return true;
  }

  void close(Queue<Result> events) {
    _completer.complete(_list);
  }
}

/// Request for a [StreamQueue.cancel] call.
///
/// The request needs no events, it just waits in the request queue
/// until all previous events are fulfilled, then it cancels the stream queue
/// source subscription.
class _CancelRequest implements _EventRequest {
  /// Completer for the future returned by the `cancel` call.
  final Completer _completer = new Completer();

  /// The [StreamQueue] object that has this request queued.
  ///
  /// When the event is completed, it needs to cancel the active subscription
  /// of the `StreamQueue` object, if any.
  final StreamQueue _streamQueue;

  _CancelRequest(this._streamQueue);

  /// The future completed when the cancel request is completed.
  Future get future => _completer.future;

  bool addEvents(Queue<Result> events) {
    _shutdown();
    return true;
  }

  void close(_) {
    _shutdown();
  }

  void _shutdown() {
    if (_streamQueue._isDone) {
      _completer.complete();
    } else {
      _streamQueue._ensureListening();
      _completer.complete(_streamQueue._dispose().cancel());
    }
  }
}

/// Request for a [StreamQueue.rest] call.
///
/// The request is always complete, it just waits in the request queue
/// until all previous events are fulfilled, then it takes over the
/// stream events subscription and creates a stream from it.
class _RestRequest<T> implements _EventRequest {
  /// Completer for the stream returned by the `rest` call.
  final _completer = new StreamCompleter<T>();

  /// The [StreamQueue] object that has this request queued.
  ///
  /// When the event is completed, it needs to cancel the active subscription
  /// of the `StreamQueue` object, if any.
  final StreamQueue<T> _streamQueue;

  _RestRequest(this._streamQueue);

  /// The stream which will contain the remaining events of [_streamQueue].
  Stream<T> get stream => _completer.stream;

  bool addEvents(Queue<Result> events) {
    _completeStream(events);
    return true;
  }

  void close(Queue<Result> events) {
    _completeStream(events);
  }

  void _completeStream(Queue<Result> events) {
    if (events.isEmpty) {
      if (_streamQueue._isDone) {
        _completer.setEmpty();
      } else {
        _completer.setSourceStream(_getRestStream());
      }
    } else {
      // There are prefetched events which needs to be added before the
      // remaining stream.
      var controller = new StreamController<T>();
      for (var event in events) {
        event.addTo(controller);
      }
      controller.addStream(_getRestStream(), cancelOnError: false)
                .whenComplete(controller.close);
      _completer.setSourceStream(controller.stream);
    }
  }

  /// Create a stream from the rest of [_streamQueue]'s subscription.
  Stream<T> _getRestStream() {
    if (_streamQueue._isDone) {
      var controller = new StreamController<T>()..close();
      return controller.stream;
      // TODO(lrn). Use the following when 1.11 is released.
      // return new Stream<T>.empty();
    }
    if (_streamQueue._subscription == null) {
      return _streamQueue._sourceStream;
    }
    var subscription = _streamQueue._dispose();
    subscription.resume();
    return new SubscriptionStream<T>(subscription);
  }
}

/// Request for a [StreamQueue.hasNext] call.
///
/// Completes the [future] with `true` if it sees any event,
/// but doesn't consume the event.
/// If the request is closed without seeing an event, then
/// the [future] is completed with `false`.
class _HasNextRequest<T> implements _EventRequest {
  final _completer = new Completer<bool>();

  Future<bool> get future => _completer.future;

  bool addEvents(Queue<Result> events) {
    if (events.isNotEmpty) {
      _completer.complete(true);
      return true;
    }
    return false;
  }

  void close(_) {
    _completer.complete(false);
  }
}

/// Request for a [StreamQueue.fork] call.
class _ForkRequest<T> implements _EventRequest {
  /// Completer for the stream used by the queue by the `fork` call.
  StreamCompleter<T> _completer;

  StreamQueue<T> queue;

  /// The [StreamQueue] object that has this request queued.
  final StreamQueue<T> _streamQueue;

  _ForkRequest(this._streamQueue) {
    _completer = new StreamCompleter();
    queue = new StreamQueue(_completer.stream);
  }

  bool addEvents(Queue<Result> events) {
    _completeStream(events);
    return true;
  }

  void close(Queue<Result> events) {
    _completeStream(events);
  }

  void _completeStream(Queue<Result> events) {
    if (events.isEmpty) {
      if (_streamQueue._isDone) {
        _completer.setEmpty();
      } else {
        _completer.setSourceStream(_streamQueue._sourceStream.fork());
      }
    } else {
      // There are prefetched events which need to be added before the
      // remaining stream.
      var controller = new StreamController<T>();
      for (var event in events) {
        event.addTo(controller);
      }

      var fork = _streamQueue._sourceStream.fork();
      controller.addStream(fork, cancelOnError: false)
          .whenComplete(controller.close);
      _completer.setSourceStream(controller.stream);
    }
  }
}
