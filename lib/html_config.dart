// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@deprecated
library test.html_config;

import 'src/deprecated/simple_configuration.dart';

/// This is a stub class used to preserve compatibility with unittest 0.11.*.
///
/// It will be removed before the next version is released.
@deprecated
class HtmlConfiguration extends SimpleConfiguration {
  HtmlConfiguration(bool isLayoutTest);

  void processMessage(e) {}
}

@deprecated
void useHtmlConfiguration([bool isLayoutTest]) {}
