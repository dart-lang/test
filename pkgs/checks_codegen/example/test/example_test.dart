// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  test('uses generated extensions', () {
    final data = Int64List(10);
    check(data)
      ..elementSizeInBytes.equals(8)
      ..lengthInBytes.equals(80);
  });
}
