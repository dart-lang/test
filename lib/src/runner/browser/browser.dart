// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.browser.browser;

import 'dart:async';

/// An interface for running browser instances.
///
/// This is intentionally coarse-grained: browsers are controlled primary from
/// inside a single tab. Thus this interface only provides support for closing
/// the browser and seeing if it closes itself.
///
/// Any errors starting or running the browser process are reported through
/// [onExit].
abstract class Browser {
  /// A future that completes when the browser exits.
  ///
  /// If there's a problem starting or running the browser, this will complete
  /// with an error.
  Future get onExit;

  /// Kills the browser process.
  ///
  /// Returns the same [Future] as [onExit], except that it won't emit
  /// exceptions.
  Future close();
}
