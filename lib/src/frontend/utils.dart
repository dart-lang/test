// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Returns a [Future] that completes after the [event loop][] has run the given
/// number of [times] (20 by default).
///
/// [event loop]: https://webdev.dartlang.org/articles/performance/event-loop#darts-event-loop-and-queues
///
/// Awaiting this approximates waiting until all asynchronous work (other than
/// work that's waiting for external resources) completes.
Future pumpEventQueue({int times}) {
  times ??= 20;
  if (times == 0) return new Future.value();
  // Use [new Future] future to allow microtask events to finish. The [new
  // Future.value] constructor uses scheduleMicrotask itself and would therefore
  // not wait for microtask callbacks that are scheduled after invoking this
  // method.
  return new Future(() => pumpEventQueue(times: times - 1));
}
