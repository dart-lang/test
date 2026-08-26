// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import '../load_suite.dart';

/// A mixin containing shared logic for test reporters.
mixin ReporterMixin {
  /// The set of all subscriptions to various streams.
  final Set<StreamSubscription> subscriptions = <StreamSubscription>{};

  bool get printPath;
  bool get printPlatform;
  String get colorBold => '';
  String get colorGray => '';
  String get colorNone => '';

  void cancelSubscriptions() {
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    subscriptions.clear();
  }

  /// Returns a representation of [duration] as `MM:SS`.
  String formatTimeString(Duration duration) {
    return "${duration.inMinutes.toString().padLeft(2, '0')}:"
        "${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  /// Returns a description of [liveTest].
  ///
  /// This differs from the test's own description in that it may also include
  /// the suite's name.
  String testDescription(LiveTest liveTest) {
    var name = liveTest.test.name;

    if (printPath &&
        liveTest.suite is! LoadSuite &&
        liveTest.suite.path != null) {
      name = '${liveTest.suite.path}: $name';
    }

    if (printPlatform) {
      name =
          '[${liveTest.suite.platform.runtime.name}, '
          '${liveTest.suite.platform.compiler.name}] $name';
    }

    if (liveTest.suite is LoadSuite) {
      name = '$colorBold$colorGray$name$colorNone';
    }

    return name;
  }
}
