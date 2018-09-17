// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../backend/invoker.dart';

/// Runs [body] with special error-handling behavior.
///
/// Errors emitted [body] will still cause the current test to fail, but they
/// won't cause it to *stop*. In particular, they won't remove any outstanding
/// callbacks registered outside of [body].
///
/// This may only be called within a test.
Future errorsDontStopTest(body()) {
  var completer = Completer();

  Invoker.current.addOutstandingCallback();
  Invoker.current.waitForOutstandingCallbacks(() {
    Future.sync(body).whenComplete(completer.complete);
  }).then((_) => Invoker.current.removeOutstandingCallback());

  return completer.future;
}
