import 'dart:async';

import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/state.dart'; // ignore: implementation_imports

import '../engine.dart';
import '../load_exception.dart';
import '../load_suite.dart';

/// Shared logic for reporters.
mixin ReporterMixin {
  bool get printPath;
  bool get printPlatform;
  Engine get engine;
  StringSink get sink;
  String get bold;
  String get gray;
  String get noColor;

  /// Returns a description of [liveTest].
  ///
  /// This differs from the test's own description in that it may also include
  /// the suite's name.
  String formatDescription(LiveTest liveTest) {
    var name = liveTest.test.name;

    if (printPath &&
        liveTest.suite != null &&
        liveTest.suite is! LoadSuite &&
        liveTest.suite.path != null) {
      name = '${liveTest.suite.path}: $name';
    }

    if (printPlatform && liveTest.suite != null) {
      name =
          '[${liveTest.suite.platform.runtime.name}, '
          '${liveTest.suite.platform.compiler.name}] $name';
    }

    if (liveTest.suite is LoadSuite) name = '$bold$gray$name$noColor';

    return name;
  }
}
