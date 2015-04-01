// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.deprecated.test_case;

/// This is a stub class used to preserve compatibility with unittest 0.11.*.
///
/// It will be removed before the next version is released.
@deprecated
abstract class TestCase {
  int get id;
  String get description;
  String get message;
  String get result;
  bool get passed;
  StackTrace get stackTrace;
  String get currentGroup;
  DateTime get startTime;
  Duration get runningTime;
  bool get enabled;
  final isComplete = false;
}
