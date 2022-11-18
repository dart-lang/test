// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:checks/checks.dart';
import 'package:checks/src/checks.dart' show softCheckAsync;
import 'package:test/scaffolding.dart';

void main() {
  group('FutureChecks', () {
    test('completes', () async {
      (await checkThat(_futureSuccess()).completes()).equals(42);

      final rejection = await softCheckAsync(_futureFail(), (f) async {
        await f.completes();
      });
      checkThat(rejection)
          .isNotNull()
          .has((r) => r.which, 'which')
          .isNotNull()
          .single
          .contains('Threw UnimplementedError');
    });

    test('throws', () async {
      (await checkThat(_futureFail()).throws<UnimplementedError>())
          .has((p0) => p0.message, 'message')
          .isNull();

      // TODO: validate the success case
      // TODO: validate type mismatch case
    });
  });

  group('StreamChecks', () {
    test('emits', () async {
      (await checkThat(StreamQueue(_countingStream(5))).emits()).equals(0);
      // TODO: empty
      // TODO: error in stream
      // TODO: wrong item
    });

    test('emitsThrough', () async {
      (await checkThat(StreamQueue(_countingStream(5))).emitsThrough((p0) {
        p0.equals(4);
      }));
      // TODO: item not found
    });

    test('neverEmits', () async {
      (await checkThat(StreamQueue(_countingStream(5))).neverEmits((p0) {
        p0.equals(5);
      }));
      // TODO: item found
    });
  });

  group('ChainAsync', () {
    test('that', () async {
      await checkThat(_futureSuccess()).completes().that((r) => r.equals(42));
    });
  });
}

Future<int> _futureSuccess() => Future.microtask(() => 42);
Future<int> _futureFail() => Future.error(UnimplementedError());
Stream<int> _countingStream(int count) =>
    Stream.fromIterable(Iterable<int>.generate(count, (index) => index));
