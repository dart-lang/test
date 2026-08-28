// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Deprecated(
  'package:test_api is not intended for general use. '
  'Please use package:test.',
)
library;

export 'hooks.dart' show TestFailure;
export 'scaffolding.dart';

final testDebugStopwatch = Stopwatch()..start();

String debugTimestamp() {
  final elapsed = testDebugStopwatch.elapsed;
  final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  final millis = elapsed.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
  return '$minutes:$seconds.$millis';
}
