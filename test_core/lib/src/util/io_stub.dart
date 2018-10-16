// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../backend/runtime.dart';
import '../backend/suite_platform.dart';

SuitePlatform currentPlatform(Runtime runtime) => throw UnsupportedError(
    'Getting the current platform is only supported where dart:io exists');
