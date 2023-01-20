// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../test_shared.dart';

void main() {
  group('ThrowsChecks', () {
    group('throws', () {
      test('succeeds for happy case', () {
        checkThat(() => throw StateError('oops!')).throws<StateError>();
      });
      test('fails for functions that return normally', () {
        checkThat(() {}).isRejectedBy(it()..throws<StateError>(),
            hasActualThat: it()
              ..deepEquals(['a function that returned <null>']),
            hasWhichThat: it()..deepEquals(['did not throw']));
      });
      test('fails for functions that throw the wrong type', () {
        checkThat(() => throw StateError('oops!')).isRejectedBy(
          it()..throws<ArgumentError>(),
          hasActualThat: it()
            ..deepEquals(['a function that threw error <Bad state: oops!>']),
          hasWhichThat: it()..deepEquals(['did not throw an ArgumentError']),
        );
      });
    });

    group('returnsNormally', () {
      test('succeeds for happy case', () {
        checkThat(() => 1).returnsNormally().equals(1);
      });
      test('fails for functions that throw', () {
        checkThat(() {
          Error.throwWithStackTrace(
              StateError('oops!'), StackTrace.fromString('fake trace'));
        }).isRejectedBy(it()..returnsNormally(),
            hasActualThat: it()..deepEquals(['a function that throws']),
            hasWhichThat: it()
              ..deepEquals(['threw <Bad state: oops!>', 'fake trace']));
      });
    });
  });
}
