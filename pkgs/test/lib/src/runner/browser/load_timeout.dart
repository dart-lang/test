// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// How much earlier than the suite load timeout to give up on the browser.
///
/// The browser's error includes its output, so it should win the race against
/// the generic timeout on the load suite.
const _loadTimeoutMargin = Duration(seconds: 1);

/// How long to wait for a browser to load a compiled suite, or `null` to wait
/// indefinitely.
///
/// The [remainingLoadTime] is how long remains before the load suite times
/// out, from `PlatformPlugin.remainingLoadTime`. When there is a limit, give
/// up on the browser shortly before it. When there is none, because the suite
/// load timeout is `none` or isn't configured, don't time out the browser
/// either.
Duration? browserLoadTimeout(Duration? remainingLoadTime) {
  if (remainingLoadTime == null) return null;
  var timeout = remainingLoadTime - _loadTimeoutMargin;
  return timeout.isNegative ? Duration.zero : timeout;
}
