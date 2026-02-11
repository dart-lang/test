// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:math' as math;

final _rand = math.Random.secure();

/// Returns a random 64 bit token suitable as a url secret.
String randomUrlSecret() =>
    base64Url.encode(List.generate(8, (_) => _rand.nextInt(256)));
