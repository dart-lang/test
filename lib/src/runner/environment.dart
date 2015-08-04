// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.environment;

import '../util/cancelable_future.dart';

/// The abstract class of environments in which test suites are
/// loaded—specifically, browsers and the Dart VM.
abstract class Environment {
  /// The URL of the Dart VM Observatory for this environment, or `null` if this
  /// environment doesn't run the Dart VM or the URL couldn't be detected.
  Uri get observatoryUrl;

  /// Displays information indicating that the test runner is paused.
  ///
  /// The returned future will complete when the user takes action within the
  /// environment that should unpause the runner. If the runner is unpaused
  /// elsewhere, the future should be canceled.
  CancelableFuture displayPause();
}
