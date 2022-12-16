// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

final _rand = math.Random();

/// Returns a random alphanumeric string ([a-zA-Z0-9]), which is suitable as
/// a url secret.
String randomUrlSecret(int length) {
  var buffer = StringBuffer();
  while (buffer.length < length) {
    buffer.write(_alphaChars[_rand.nextInt(_alphaChars.length)]);
  }
  return buffer.toString();
}

const _alphaChars =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
