// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../../backend/runtime.dart';
import '../executable_settings.dart';

/// Default settings for starting browser executables.
final defaultSettings = new UnmodifiableMapView({
  Runtime.chrome: new ExecutableSettings(
      linuxExecutable: 'google-chrome',
      macOSExecutable:
          '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      windowsExecutable: r'Google\Chrome\Application\chrome.exe'),
  Runtime.contentShell: new ExecutableSettings(
      linuxExecutable: 'content_shell',
      macOSExecutable: 'content_shell',
      windowsExecutable: 'content_shell.exe'),
  Runtime.dartium: new ExecutableSettings(
      linuxExecutable: 'dartium',
      macOSExecutable: 'dartium',
      windowsExecutable: 'dartium.exe'),
  Runtime.firefox: new ExecutableSettings(
      linuxExecutable: 'firefox',
      macOSExecutable: '/Applications/Firefox.app/Contents/MacOS/firefox-bin',
      windowsExecutable: r'Mozilla Firefox\firefox.exe'),
  Runtime.internetExplorer: new ExecutableSettings(
      windowsExecutable: r'Internet Explorer\iexplore.exe'),
  Runtime.phantomJS: new ExecutableSettings(
      linuxExecutable: 'phantomjs',
      macOSExecutable: 'phantomjs',
      windowsExecutable: 'phantomjs.exe'),
  Runtime.safari: new ExecutableSettings(
      macOSExecutable: '/Applications/Safari.app/Contents/MacOS/Safari')
});
