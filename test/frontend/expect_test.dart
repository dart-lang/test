// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/src/backend/state.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group("returned Future", () {
    test("completes immediately for a sync matcher", () {
      expect(expect(true, isTrue), completes);
    });

    test("contains the expect failure", () {
      expect(expect(new Future.value(true), completion(isFalse)),
          throwsA(isTestFailure(anything)));
    });

    test("contains an async error", () {
      expect(expect(new Future.error("oh no"), completion(isFalse)),
          throwsA("oh no"));
    });
  });
}
