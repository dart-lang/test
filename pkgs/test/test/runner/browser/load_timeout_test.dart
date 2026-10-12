// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/src/runner/browser/load_timeout.dart';
import 'package:test/test.dart';

void main() {
  test('does not time out when loading has no time limit', () {
    expect(browserLoadTimeout(null), isNull);
  });

  test('gives up shortly before a long remaining load time', () {
    expect(
      browserLoadTimeout(const Duration(minutes: 2)),
      const Duration(minutes: 1, seconds: 59),
    );
  });

  test('gives up shortly before a short remaining load time', () {
    expect(
      browserLoadTimeout(const Duration(seconds: 5)),
      const Duration(seconds: 4),
    );
  });

  test('gives up immediately when less time remains than the margin', () {
    expect(
      browserLoadTimeout(const Duration(milliseconds: 500)),
      Duration.zero,
    );
  });

  test('gives up immediately when the load has run out of time', () {
    expect(browserLoadTimeout(const Duration(seconds: -1)), Duration.zero);
  });
}
