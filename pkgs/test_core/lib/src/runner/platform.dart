// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_api/backend.dart';

import 'environment.dart';
import 'load_suite.dart' as load_suite;
import 'runner_suite.dart';
import 'suite.dart';

/// A class that defines a platform for which test suites can be loaded.
///
/// A minimal plugin must define [loadChannel], which connects to a client in
/// which the tests are defined. This is enough to support most of the test
/// runner's functionality.
///
/// In order to support interactive debugging, a plugin must override [load] as
/// well, which returns a [RunnerSuite] that can contain a custom [Environment]
/// and control debugging metadata such as [RunnerSuite.isDebugging] and
/// [RunnerSuite.onDebugging]. The plugin must create this suite by calling the
/// [deserializeSuite] helper function.
///
/// A platform plugin can be registered by passing it to [Loader.new]'s
/// `plugins` parameter.
abstract class PlatformPlugin {
  /// How long remains before the suite load timeout fails the suite being
  /// loaded.
  ///
  /// Returns `null` when the load can't time out, because the suite load timeout
  /// is `none` or timeouts are ignored, and when not called during [load].
  ///
  /// Platforms can read this during [load] to time out a step of loading with a
  /// more specific error before the suite fails with a generic timeout. The
  /// value is only meaningful while [load] is running; callbacks a platform
  /// registers during [load] may see a stale value when they run later.
  static Duration? get remainingLoadTime => load_suite.remainingLoadTime;

  /// Loads the runner suite for the test file at [path] using [platform], with
  /// [suiteConfig] encoding the suite-specific configuration.
  ///
  /// By default, this just calls [loadChannel] and passes its result to
  /// [deserializeSuite]. However, it can be overridden to provide more
  /// fine-grained control over the [RunnerSuite], including providing a custom
  /// implementation of [Environment].
  ///
  /// Subclasses overriding this method must call [deserializeSuite] in
  /// `platform_helpers.dart` to obtain a [RunnerSuiteController]. They must
  /// pass the opaque [message] parameter to the [deserializeSuite] call.
  Future<RunnerSuite?> load(
    String path,
    SuitePlatform platform,
    SuiteConfiguration suiteConfig,
    Map<String, Object?> message,
  );

  Future closeEphemeral() async {}

  Future close() async {}
}
