// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.runner.vm.isolate_test;

import 'dart:async';
import 'dart:isolate';

import '../../backend/metadata.dart';
import '../../backend/test.dart';
import 'vm_test.dart';

/// A test in another isolate.
class IsolateTest extends VMTest {
  final SendPort _sendPort;

  IsolateTest(String name, Metadata metadata, SendPort sendPort)
    : _sendPort = sendPort, super(name, metadata, sendPort.send);

  Stream sendRunCommand() {
    ReceivePort receivePort = new ReceivePort();
    send({
      'command': 'run',
      'reply': receivePort.sendPort
    });
    return receivePort;
  }

  Test change({String name, Metadata metadata}) {
    if (name == name && metadata == this.metadata) return this;
    if (name == null) name = this.name;
    if (metadata == null) metadata = this.metadata;
    return new IsolateTest(name, metadata, _sendPort);
  }
}
