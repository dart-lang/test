// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports

import '../executable_settings.dart';
import 'browser.dart';
import 'chromium.dart';

/// A class for running an instance of Microsoft Edge, a Chromium-based browser.
class MicrosoftEdge extends Browser {
  @override
  String get name => 'Edge';

  MicrosoftEdge(Uri url, Configuration configuration,
      {ExecutableSettings? settings})
      : super(() => ChromiumBasedBrowser.microsoftEdge.spawn(
              url,
              configuration,
              settings: settings,
            ));
}
