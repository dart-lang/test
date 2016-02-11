// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../backend/group.dart';
import '../../backend/metadata.dart';
import '../../backend/test.dart';
import '../../backend/test_platform.dart';
import '../../util/io.dart';
import '../../util/remote_exception.dart';
import '../environment.dart';
import '../load_exception.dart';
import '../runner_suite.dart';
import '../runner_test.dart';
import 'environment.dart';

/// A class that defines a platform for which test suites can be loaded.
///
/// A minimal plugin must define [platforms], which indicates the platforms it
/// supports, and [loadChannel], which connects to a client in which the tests
/// are defined. This is enough to support most of the test runner's
/// functionality.
///
/// In order to support interactive debugging, a plugin must override [load] as
/// well, which returns a [RunnerSuite] that can contain a custom [Environment]
/// and control debugging metadata such as [RunnerSuite.isDebugging] and
/// [RunnerSuite.onDebugging]. To make this easier, implementations can call
/// [deserializeSuite].
///
/// A platform plugin can be registered with [Loader.registerPlatformPlugin].
abstract class PlatformPlugin {
  /// The platforms supported by this plugin.
  ///
  /// A plugin may declare support for existing platform, in which case it
  /// overrides the previous loading functionality for that platform.
  List<TestPlatform> get platforms;

  /// Loads and establishes a connection with the test file at [path] using
  /// [platform].
  ///
  /// This returns a channel that's connected to a remote client. The client
  /// must connect it to a channel returned by [serializeGroup]. The default
  /// implementation of [load] will take care of wrapping it up in a
  /// [RunnerSuite] and running the tests when necessary.
  ///
  /// The returned channel may emit exceptions, indicating that the suite failed
  /// to load or crashed later on. If the channel is closed by the caller, that
  /// indicates that the suite is no longer needed and its resources may be
  /// released.
  ///
  /// The [platform] is guaranteed to be a member of [platforms].
  StreamChannel loadChannel(String path, TestPlatform platform);

  /// Loads the runner suite for the test file at [path] using [platform], with
  /// [metadata] parsed from the test file's top-level annotations.
  ///
  /// By default, this just calls [loadChannel] and passes its result to
  /// [deserializeSuite]. However, it can be overridden to provide more
  /// fine-grained control over the [RunnerSuite], including providing a custom
  /// implementation of [Environment].
  ///
  /// It's recommended that subclasses overriding this method call
  /// [deserializeSuite] to obtain a [RunnerSuiteController].
  Future<RunnerSuite> load(String path, TestPlatform platform,
      Metadata metadata) async {
    // loadChannel may throw an exception. That's fine; it will cause the
    // LoadSuite to emit an error, which will be presented to the user.
    var channel = loadChannel(path, platform);
    var controller = await deserializeSuite(
        path, platform, metadata, new PluginEnvironment(), channel);
    return controller.suite;
  }

  /// A helper method for creating a [RunnerSuiteController] containing tests
  /// that communicate over [channel].
  ///
  /// This is notionally a protected method. It may be called by subclasses, but
  /// it shouldn't be accessed by externally.
  ///
  /// This returns a controller so that the caller has a chance to control the
  /// runner suite's debugging state based on plugin-specific logic.
  Future<RunnerSuiteController> deserializeSuite(String path,
      TestPlatform platform, Metadata metadata, Environment environment,
      StreamChannel channel) async {
    var disconnector = new Disconnector();
    var suiteChannel = new MultiChannel(channel.transform(disconnector));

    suiteChannel.sink.add({
      'platform': platform.identifier,
      'metadata': metadata.serialize(),
      'os': platform == TestPlatform.vm ? currentOS.name : null
    });

    var completer = new Completer();

    handleError(error, stackTrace) {
      disconnector.disconnect();

      if (completer.isCompleted) {
        // If we've already provided a controller, send the error to the
        // LoadSuite. This will cause the virtual load test to fail, which will
        // notify the user of the error.
        Zone.current.handleUncaughtError(error, stackTrace);
      } else {
        completer.completeError(error, stackTrace);
      }
    }

    suiteChannel.stream.listen((response) {
      switch (response["type"]) {
        case "print":
          print(response["line"]);
          break;

        case "loadException":
          handleError(
              new LoadException(path, response["message"]),
              new Trace.current());
          break;

        case "error":
          var asyncError = RemoteException.deserialize(response["error"]);
          handleError(
              new LoadException(path, asyncError.error),
              asyncError.stackTrace);
          break;

        case "success":
          completer.complete(
              _deserializeGroup(suiteChannel, response["root"]));
          break;
      }
    }, onError: handleError, onDone: () {
      if (completer.isCompleted) return;
      completer.completeError(
          new LoadException(
              path, "Connection closed before test suite loaded."),
          new Trace.current());
    });

    return new RunnerSuiteController(
        environment,
        await completer.future,
        path: path,
        platform: platform,
        os: currentOS,
        onClose: disconnector.disconnect);
  }

  /// Deserializes [group] into a concrete [Group].
  Group _deserializeGroup(MultiChannel suiteChannel, Map group) {
    var metadata = new Metadata.deserialize(group['metadata']);
    return new Group(group['name'], group['entries'].map((entry) {
      if (entry['type'] == 'group') {
        return _deserializeGroup(suiteChannel, entry);
      }

      return _deserializeTest(suiteChannel, entry);
    }),
        metadata: metadata,
        setUpAll: _deserializeTest(suiteChannel, group['setUpAll']),
        tearDownAll: _deserializeTest(suiteChannel, group['tearDownAll']));
  }

  /// Deserializes [test] into a concrete [Test] class.
  ///
  /// Returns `null` if [test] is `null`.
  Test _deserializeTest(MultiChannel suiteChannel, Map test) {
    if (test == null) return null;

    var metadata = new Metadata.deserialize(test['metadata']);
    var testChannel = suiteChannel.virtualChannel(test['channel']);
    return new RunnerTest(test['name'], metadata, testChannel);
  }
}
