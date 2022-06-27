// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  test('throws', () {
    checkThat(() => throw StateError('oops!')).throws<StateError>();

    checkThat(
      softCheck<void Function()>(() {}, (p0) => p0.throws<StateError>()),
    ).isARejection(actual: 'Returned <null>', which: ['Did not throw']);
    checkThat(
      softCheck<void Function()>(
        () => throw StateError('oops!'),
        (p0) => p0.throws<ArgumentError>(),
      ),
    ).isARejection(
      actual: 'Completed to error Bad state: oops!',
      which: ['Is not an ArgumentError'],
    );
  });
}
