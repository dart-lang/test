// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

/// The key used to look up [SuiteChannelManager.current] in a zone.
final _currentKey = Object();

/// A class that connects incoming and outgoing channels with the same names.
class SuiteChannelManager {
  /// Connections from the test runner that have yet to connect to corresponding
  /// calls to [suiteChannel] within this worker.
  final _incomingConnections = <String, StreamChannel<Object?>>{};

  /// Connections from calls to [suiteChannel] that have yet to connect to
  /// corresponding connections from the test runner.
  final _outgoingConnections = <String, StreamChannelCompleter<Object?>>{};

  /// The channel names that have already been used.
  final _names = <String>{};

  /// Returns the current manager, or `null` if this isn't called within a call
  /// to [asCurrent].
  static SuiteChannelManager? get current =>
      Zone.current[_currentKey] as SuiteChannelManager?;

  /// Runs [body] with [this] as [SuiteChannelManager.current].
  ///
  /// This is zone-scoped, so [this] will be the current configuration in any
  /// asynchronous callbacks transitively created by [body].
  T asCurrent<T>(T Function() body) =>
      runZoned(body, zoneValues: {_currentKey: this});

  /// Creates a connection to the test runnner's channel with the given [name].
  StreamChannel<Object?> connectOut(String name) {
    if (_incomingConnections.containsKey(name)) {
      return (_incomingConnections[name])!;
    } else if (_names.contains(name)) {
      throw StateError('Duplicate suiteChannel() connection "$name".');
    } else {
      _names.add(name);
      var completer = StreamChannelCompleter<Object?>();
      _outgoingConnections[name] = completer;
      return completer.channel;
    }
  }

  /// Connects [channel] to this worker's channel with the given [name].
  void connectIn(String name, StreamChannel<Object?> channel) {
    if (_outgoingConnections.containsKey(name)) {
      _outgoingConnections.remove(name)!.setChannel(channel);
    } else if (_incomingConnections.containsKey(name)) {
      throw StateError('Duplicate RunnerSuite.channel() connection "$name".');
    } else {
      _incomingConnections[name] = channel;
    }
  }
}
