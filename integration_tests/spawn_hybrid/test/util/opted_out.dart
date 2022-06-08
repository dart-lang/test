// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// @dart=2.9
import 'package:stream_channel/stream_channel.dart';

// Would fail if null safety were enabled.
int x;

void hybridMain(StreamChannel channel) {
  channel.sink
    ..add(1)
    ..add(2)
    ..add(3)
    ..close();
}
