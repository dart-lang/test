// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore: illegal_language_version_override
// @dart=2.9

import 'package:test/test.dart';

import 'common/is_opted_out.dart';

void main() {
  test('unsound behavior', () async {
    expect(isOptedOut, true);
  });
}
