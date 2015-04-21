// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/src/backend/metadata.dart';
import 'package:test/src/backend/test_platform.dart';
import 'package:test/src/frontend/timeout.dart';
import 'package:test/src/frontend/skip.dart';
import 'package:test/test.dart';

void main() {
  group("onPlatform", () {
    test("parses a valid map", () {
      var metadata = new Metadata.parse(onPlatform: {
        "chrome": new Timeout.factor(2),
        "vm": [new Skip(), new Timeout.factor(3)]
      });

      var key = metadata.onPlatform.keys.first;
      expect(key.evaluate(TestPlatform.chrome), isTrue);
      expect(key.evaluate(TestPlatform.vm), isFalse);
      var value = metadata.onPlatform.values.first;
      expect(value.timeout.scaleFactor, equals(2));


      key = metadata.onPlatform.keys.last;
      expect(key.evaluate(TestPlatform.vm), isTrue);
      expect(key.evaluate(TestPlatform.chrome), isFalse);
      value = metadata.onPlatform.values.last;
      expect(value.skip, isTrue);
      expect(value.timeout.scaleFactor, equals(3));
    });

    test("refuses an invalid value", () {
      expect(() {
        new Metadata.parse(onPlatform: {"chrome": new TestOn("chrome")});
      }, throwsArgumentError);
    });

    test("refuses an invalid value in a list", () {
      expect(() {
        new Metadata.parse(onPlatform: {"chrome": [new TestOn("chrome")]});
      }, throwsArgumentError);
    });

    test("refuses an invalid platform selector", () {
      expect(() {
        new Metadata.parse(onPlatform: {"invalid": new Skip()});
      }, throwsFormatException);
    });

    test("refuses multiple Timeouts", () {
      expect(() {
        new Metadata.parse(onPlatform: {
          "chrome": [new Timeout.factor(2), new Timeout.factor(3)]
        });
      }, throwsArgumentError);
    });

    test("refuses multiple Skips", () {
      expect(() {
        new Metadata.parse(onPlatform: {"chrome": [new Skip(), new Skip()]});
      }, throwsArgumentError);
    });
  });
}
