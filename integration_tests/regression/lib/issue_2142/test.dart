// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Skip('https://github.com/dart-lang/test/issues/2142')
library;

import 'package:test/test.dart';
import 'import.dart';

void main() {
  test('aThing is a Thing', () {
    expect(newThing(), isA<Thing>());
  });
}

class Thing {}
