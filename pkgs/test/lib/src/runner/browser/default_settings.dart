// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import '../executable_settings.dart';

/// Default settings for starting browser executables.
final defaultSettings = UnmodifiableMapView({
  Runtime.chrome: ExecutableSettings(linuxExecutables: [
    'google-chrome'
  ], macOSExecutables: [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
  ], windowsExecutables: [
    r'Google\Chrome\Application\chrome.exe'
  ], environmentOverride: 'CHROME_EXECUTABLE'),
  Runtime.edge: ExecutableSettings(
    linuxExecutables: ['microsoft-edge-stable'],
    windowsExecutables: [r'Microsoft\Edge\Application\msedge.exe'],
    macOSExecutables: [
      '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'
    ],
    environmentOverride: 'MS_EDGE_EXECUTABLE',
  ),
  Runtime.firefox: ExecutableSettings(linuxExecutables: [
    'firefox'
  ], macOSExecutables: [
    '/Applications/Firefox.app/Contents/MacOS/firefox',
    '/Applications/Firefox.app/Contents/MacOS/firefox-bin'
  ], windowsExecutables: [
    r'Mozilla Firefox\firefox.exe'
  ], environmentOverride: 'FIREFOX_EXECUTABLE'),
  Runtime.safari: ExecutableSettings(
      macOSExecutables: ['/Applications/Safari.app/Contents/MacOS/Safari'],
      environmentOverride: 'SAFARI_EXECUTABLE'),
});
