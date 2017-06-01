// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

/// Converts a [Stream<List<int>>] to a flat byte future.
Future<List<int>> byteStreamToList(Stream<List<int>> stream) {
  return stream.fold(<int>[], (buffer, chunk) {
    buffer.addAll(chunk);
    return buffer;
  });
}

/// Returns a matcher that verifies that the result of calling `toString()`
/// matches [matcher].
Matcher toString(matcher) {
  return predicate((object) {
    expect(object.toString(), matcher);
    return true;
  }, "toString() matches $matcher");
}
