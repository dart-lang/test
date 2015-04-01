// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.stream_channel;

import 'dart:async';

/// An abstract class representing a two-way communication channel.
///
/// Subclasses can mix in [StreamChannelMixin] to get default implementations of
/// the various instance methods.
abstract class StreamChannel<T> {
  /// The stream that emits values from the other endpoint.
  Stream<T> get stream;

  /// The sink for sending values to the other endpoint.
  StreamSink<T> get sink;

  /// Creates a new [StreamChannel] that communicates over [stream] and [sink].
  factory StreamChannel(Stream<T> stream, StreamSink<T> sink) =>
      new _StreamChannel<T>(stream, sink);

  /// Connects [this] to [other], so that any values emitted by either are sent
  /// directly to the other.
  void pipe(StreamChannel<T> other);
}

/// An implementation of [StreamChannel] that simply takes a stream and a sink
/// as parameters.
///
/// This is distinct from [StreamChannel] so that it can use
/// [StreamChannelMixin].
class _StreamChannel<T> extends StreamChannelMixin<T> {
  final Stream<T> stream;
  final StreamSink<T> sink;

  _StreamChannel(this.stream, this.sink);
}

/// A mixin that implements the instance methods of [StreamChannel] in terms of
/// [stream] and [sink].
abstract class StreamChannelMixin<T> implements StreamChannel<T> {
  void pipe(StreamChannel<T> other) {
    stream.pipe(other.sink);
    other.stream.pipe(sink);
  }
}
