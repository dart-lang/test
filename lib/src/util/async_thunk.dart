// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.async_thunk;

import 'dart:async';

/// A class for running an asynchronous method body exactly once and caching its
/// result.
///
/// This should be stored as an instance variable, and [run] should be called
/// when the method is invoked with the uncached method body. The first time, it
/// runs the body; after that, it returns the future from the first run.
class AsyncThunk<T> {
  /// The completer for the method's result.
  ///
  /// This will be `null` if [run] hasn't been called yet.
  Completer<T> _completer;

  /// Whether [run] has been called yet.
  bool get hasRun => _completer != null;

  /// Runs the method body, [fn], if it hasn't been run before.
  ///
  /// If [fn] has been run before, returns the original result.
  Future<T> run(fn()) {
    if (_completer == null) {
      _completer = new Completer.sync();
      new Future.sync(fn)
          .then(_completer.complete)
          .catchError(_completer.completeError);
    }

    return _completer.future;
  }
}
