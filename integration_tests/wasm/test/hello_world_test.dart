// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('wasm')
// TODO: https://github.com/dart-lang/test/issues/2288
@OnPlatform({'windows && firefox': Skip()})
// This retry is a regression test for https://github.com/dart-lang/test/issues/2006
@Retry(2)
library;

import 'package:test/test.dart';

void main() {
  test('1 == 1', () {
    expect(1, equals(1));
  });

  test('asserts are enabled', () {
    expect(shouldFail, throwsA(isA<AssertionError>()));
  });
}

void shouldFail() {
  assert(1 == 2);
}
