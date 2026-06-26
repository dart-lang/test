// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A utility to pick a platform safe default reporter for cases where a test
/// suite is run directly instead of through the test runner.
library;

export 'direct_stub.dart' if (dart.library.io) 'direct_io.dart';
