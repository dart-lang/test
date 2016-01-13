// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../backend/metadata.dart';
import 'configuration.dart';
import 'runner_suite.dart';

typedef Future<RunnerSuite> LoadVMFileHook(String path, Metadata metadata,
    Configuration config);

/// **Do not set or use this function without express permission from the test
/// package authors**.
///
/// A function that overrides the loader's default behavior for loading test
/// suites on the Dart VM. This function takes the path to the file, the
/// file's metadata, and the test runner's configuration and returns a
/// [RunnerSuite] for that file.
LoadVMFileHook loadVMFileHook;
