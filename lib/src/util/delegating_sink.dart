// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.delegating_sink;

// TODO(nweiz): Move this into package:async.
/// An implementation of [Sink] that forwards all calls to a wrapped [Sink].
///
/// This can also be used on a subclass to make it look like a normal [Sink].
class DelegatingSink<T> implements Sink<T> {
  /// The wrapped [Sink].
  final Sink _inner;

  DelegatingSink(this._inner);

  void add(T data) {
    _inner.add(data);
  }

  void close() {
    _inner.close();
  }
}
