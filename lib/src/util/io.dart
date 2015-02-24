// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.util.io;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns whether the current Dart version supports [Isolate.kill].
final bool supportsIsolateKill = _supportsIsolateKill;
bool get _supportsIsolateKill {
  // This isn't 100% accurate, since early 1.9 dev releases didn't support
  // Isolate.kill(), but it's very unlikely anyone will be using them.
  // TODO(nweiz): remove this when we no longer support older Dart versions.
  var path = p.join(p.dirname(p.dirname(Platform.executable)), 'version');
  return new File(path).readAsStringSync().startsWith('1.9');
}

// TODO(nweiz): Make this check [stdioType] once that works within "pub run".
/// Whether "special" strings such as Unicode characters or color escapes are
/// safe to use.
///
/// On Windows or when not printing to a terminal, only printable ASCII
/// characters should be used.
bool get canUseSpecialChars =>
    Platform.operatingSystem != 'windows' &&
    Platform.environment["_UNITTEST_USE_COLOR"] != "false";

/// Gets a "special" string (ANSI escape or Unicode).
///
/// On Windows or when not printing to a terminal, returns something else since
/// those aren't supported.
String getSpecial(String special, [String onWindows = '']) =>
    canUseSpecialChars ? special : onWindows;

/// Creates a temporary directory and passes its path to [fn].
///
/// Once the [Future] returned by [fn] completes, the temporary directory and
/// all its contents are deleted. [fn] can also return `null`, in which case
/// the temporary directory is deleted immediately afterwards.
///
/// Returns a future that completes to the value that the future returned from
/// [fn] completes to.
Future withTempDir(Future fn(String path)) {
  return new Future.sync(() {
    // TODO(nweiz): Empirically test whether sync or async functions perform
    // better here when starting a bunch of isolates.
    var tempDir = Directory.systemTemp.createTempSync('unittest_');
    return new Future.sync(() => fn(tempDir.path))
        .whenComplete(() => tempDir.deleteSync(recursive: true));
  });
}
