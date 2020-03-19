// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.7

import 'dart:async';
import 'dart:io';

import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'browser.dart';
import 'default_settings.dart';
import '../executable_settings.dart';

/// A class for running an instance of Internet Explorer.
///
/// Any errors starting or running the process are reported through [onExit].
class InternetExplorer extends Browser {
  @override
  final name = 'Internet Explorer';

  InternetExplorer(url, {ExecutableSettings settings})
      : super(() => _startBrowser(url, settings));

  /// Starts a new instance of Internet Explorer open to the given [url], which
  /// may be a [Uri] or a [String].
  static Future<Process> _startBrowser(url, ExecutableSettings settings) {
    settings ??= defaultSettings[Runtime.internetExplorer];

    return Process.start(settings.executable, [
      '-extoff',
      '$url',
      ...settings.arguments,
    ]);
  }
}
