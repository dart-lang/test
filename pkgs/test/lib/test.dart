// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The main test library.
///
/// This library exports the core test APIs, including `test()`, `group()`,
/// `setUp()`, `tearDown()`, and `expect()`.
///
/// This is the recommended import for most test files.
/// If you want to use `package:checks` for assertions, import
/// `package:test/scaffolding.dart` instead.
library;

export 'package:matcher/expect.dart';
// Deprecated exports not surfaced through focused libraries.
// ignore: deprecated_member_use
export 'package:matcher/src/expect/expect.dart' show ErrorFormatter;
// ignore: deprecated_member_use
export 'package:matcher/src/expect/expect_async.dart' show expectAsync;
// ignore: deprecated_member_use
export 'package:matcher/src/expect/throws_matcher.dart' show Throws, throws;
// The non-deprecated API (through a deprecated import).
// ignore: deprecated_member_use
export 'package:test_core/test_core.dart';
