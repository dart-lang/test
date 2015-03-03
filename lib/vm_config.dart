// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@deprecated
library unittest.vm_config;

import 'src/deprecated/simple_configuration.dart';

/// This is a stub class used to preserve compatibility with unittest 0.11.*.
///
/// It will be removed before the next version is released.
@deprecated
class VMConfiguration extends SimpleConfiguration {
  final String GREEN_COLOR = '\u001b[32m';
  final String RED_COLOR = '\u001b[31m';
  final String MAGENTA_COLOR = '\u001b[35m';
  final String NO_COLOR = '\u001b[0m';

  bool useColor = false;

  VMConfiguration() : super();
}

@deprecated
void useVMConfiguration() {}
