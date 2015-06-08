// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.isolate_wrapper;

import 'dart:async';
import 'dart:isolate';

// TODO(nweiz): Get rid of this when issue 6610 is fixed.
/// This is a wrapper around an [Isolate] that supports a callback that will
/// fire when [Isolate.exit] is called.
///
/// This is necessary to delete the source directory of the isolate only once
/// the Isolate completes. Note that the callback won't necessarily fire before
/// the Isolate is killed, but it comes close enough for our purposes.
///
/// This avoids implementing Isolate because there's no interface that's
/// compatible with both Dart before 1.11 and Dart after 1.11.
class IsolateWrapper {
  final Isolate _inner;

  final Function _onExit;

  Capability get pauseCapability => _inner.pauseCapability;
  SendPort get controlPort => _inner.controlPort;
  Stream get errors => _inner.errors;
  Capability get terminateCapability => _inner.terminateCapability;

  IsolateWrapper(this._inner, this._onExit);

  void addErrorListener(SendPort port) => _inner.addErrorListener(port);
  void addOnExitListener(SendPort port) => _inner.addOnExitListener(port);
  Capability pause([Capability resumeCapability]) =>
      _inner.pause(resumeCapability);
  void ping(SendPort responsePort) => _inner.ping(responsePort);
  void removeErrorListener(SendPort port) => _inner.removeErrorListener(port);
  void removeOnExitListener(SendPort port) => _inner.removeOnExitListener(port);
  void resume(Capability resumeCapability) => _inner.resume(resumeCapability);
  void setErrorsFatal(bool errorsAreFatal) =>
      _inner.setErrorsFatal(errorsAreFatal);
  String toString() => _inner.toString();

  void kill() {
    _inner.kill();
    _onExit();
  }
}
