// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
