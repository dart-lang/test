// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

import '../backend/group.dart';
import '../backend/suite.dart';
import '../backend/suite_platform.dart';
import '../backend/test.dart';
import '../utils.dart';
import 'configuration/suite.dart';
import 'environment.dart';

/// A suite produced and consumed by the test runner that has runner-specific
/// logic and lifecycle management.
///
/// This is separated from [Suite] because the backend library (which will
/// eventually become its own package) is primarily for test code itself to use,
/// for which the [RunnerSuite] APIs don't make sense.
///
/// A [RunnerSuite] can be produced and controlled using a
/// [RunnerSuiteController].
class RunnerSuite extends Suite {
  final RunnerSuiteController _controller;

  /// The environment in which this suite runs.
  Environment get environment => _controller._environment;

  /// The configuration for this suite.
  SuiteConfiguration get config => _controller._config;

  /// Whether the suite is paused for debugging.
  ///
  /// When using a dev inspector, this may also mean that the entire browser is
  /// paused.
  bool get isDebugging => _controller._isDebugging;

  /// A broadcast stream that emits an event whenever the suite is paused for
  /// debugging or resumed afterwards.
  ///
  /// The event is `true` when debugging starts and `false` when it ends.
  Stream<bool> get onDebugging => _controller._onDebuggingController.stream;

  /// Returns a channel that communicates with the remote suite.
  ///
  /// This connects to a channel created by code in the test worker calling
  /// `suiteChannel()` from `remote_platform_helpers.dart` with the same name.
  /// It can be used used to send and receive any JSON-serializable object.
  StreamChannel channel(String name) => _controller.channel(name);

  /// A shortcut constructor for creating a [RunnerSuite] that never goes into
  /// debugging mode and doesn't support suite channels.
  factory RunnerSuite(Environment environment, SuiteConfiguration config,
      Group group, SuitePlatform platform,
      {String path, AsyncFunction onClose}) {
    var controller =
        new RunnerSuiteController._local(environment, config, onClose: onClose);
    var suite = new RunnerSuite._(controller, group, path, platform);
    controller._suite = new Future.value(suite);
    return suite;
  }

  RunnerSuite._(
      this._controller, Group group, String path, SuitePlatform platform)
      : super(group, platform, path: path);

  RunnerSuite filter(bool callback(Test test)) {
    var filtered = group.filter(callback);
    filtered ??= new Group.root([], metadata: metadata);
    return new RunnerSuite._(_controller, filtered, path, platform);
  }

  /// Closes the suite and releases any resources associated with it.
  Future close() => _controller._close();
}

/// A class that exposes and controls a [RunnerSuite].
class RunnerSuiteController {
  /// The suite controlled by this controller.
  Future<RunnerSuite> get suite => _suite;
  Future<RunnerSuite> _suite;

  /// The backing value for [suite.environment].
  final Environment _environment;

  /// The configuration for this suite.
  final SuiteConfiguration _config;

  /// A channel that communicates with the remote suite.
  final MultiChannel _suiteChannel;

  /// The function to call when the suite is closed.
  final AsyncFunction _onClose;

  /// The backing value for [suite.isDebugging].
  bool _isDebugging = false;

  /// The controller for [suite.onDebugging].
  final _onDebuggingController = new StreamController<bool>.broadcast();

  /// The channel names that have already been used.
  final _channelNames = new Set<String>();

  RunnerSuiteController(this._environment, this._config, this._suiteChannel,
      Future<Group> groupFuture, SuitePlatform platform,
      {String path, AsyncFunction onClose})
      : _onClose = onClose {
    _suite = groupFuture
        .then((group) => new RunnerSuite._(this, group, path, platform));
  }

  /// Used by [new RunnerSuite] to create a runner suite that's not loaded from
  /// an external source.
  RunnerSuiteController._local(this._environment, this._config,
      {AsyncFunction onClose})
      : _suiteChannel = null,
        _onClose = onClose;

  /// Sets whether the suite is paused for debugging.
  ///
  /// If this is different than [suite.isDebugging], this will automatically
  /// send out an event along [suite.onDebugging].
  void setDebugging(bool debugging) {
    if (debugging == _isDebugging) return;
    _isDebugging = debugging;
    _onDebuggingController.add(debugging);
  }

  /// Returns a channel that communicates with the remote suite.
  ///
  /// This connects to a channel created by code in the test worker calling
  /// `suiteChannel()` from `remote_platform_helpers.dart` with the same name.
  /// It can be used used to send and receive any JSON-serializable object.
  ///
  /// This is exposed on the [RunnerSuiteController] so that runner plugins can
  /// communicate with the workers they spawn before the associated [suite] is
  /// fully loaded.
  StreamChannel channel(String name) {
    if (!_channelNames.add(name)) {
      throw new StateError(
          'Duplicate RunnerSuite.channel() connection "$name".');
    }

    var channel = _suiteChannel.virtualChannel();
    _suiteChannel.sink
        .add({"type": "suiteChannel", "name": name, "id": channel.id});
    return channel;
  }

  /// The backing function for [suite.close].
  Future _close() => _closeMemo.runOnce(() async {
        _onDebuggingController.close();
        if (_onClose != null) await _onClose();
      });
  final _closeMemo = new AsyncMemoizer();
}
