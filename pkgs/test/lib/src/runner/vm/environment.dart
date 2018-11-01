// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:vm_service_client/vm_service_client.dart';
import 'package:test_core/src/runner/environment.dart'; // ignore: implementation_imports

/// The environment in which VM tests are loaded.
class VMEnvironment implements Environment {
  final supportsDebugging = true;
  final Uri observatoryUrl;

  /// The VM service isolate object used to control this isolate.
  final VMIsolateRef _isolate;

  VMEnvironment(this.observatoryUrl, this._isolate);

  Uri get remoteDebuggerUrl => null;

  Stream get onRestart => StreamController.broadcast().stream;

  CancelableOperation displayPause() {
    var completer = CancelableCompleter(onCancel: () => _isolate.resume());

    completer.complete(_isolate.pause().then((_) => _isolate.onPauseOrResume
        .firstWhere((event) => event is VMResumeEvent)));

    return completer.operation;
  }
}
