// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A private file used for testing `spawnHybridUri` through a package Uri i.e.
/// package:test/src/_package_hybrid_test_helper.dart`

import "package:stream_channel/stream_channel.dart";

void hybridMain(StreamChannel channel) {
  channel.sink
    ..add(1)
    ..add(2)
    ..add(3)
    ..close();
}
