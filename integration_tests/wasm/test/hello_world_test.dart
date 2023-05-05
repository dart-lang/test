// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('wasm')
// This retry is a regression test for https://github.com/dart-lang/test/issues/2006
@Retry(2)
import 'package:test/test.dart';

void main() {
  test('1 == 1', () {
    expect(1, equals(1));
  });
}
