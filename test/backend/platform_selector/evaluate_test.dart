// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:unittest/unittest.dart';
import 'package:unittest/src/backend/operating_system.dart';
import 'package:unittest/src/backend/platform_selector.dart';
import 'package:unittest/src/backend/test_platform.dart';

void main() {
  test("new PlatformSelector.parse() disallows invalid variables", () {
    expect(() => new PlatformSelector.parse("undefined"),
        throwsFormatException);
  });

  group("operator:", () {
    test("conditional", () {
      _expectEval("vm ? vm : browser", true);
      _expectEval("vm ? browser : vm", false);
      _expectEval("browser ? vm : browser", false);
      _expectEval("browser ? browser : vm", true);
    });

    test("or", () {
      _expectEval("vm || vm", true);
      _expectEval("vm || browser", true);
      _expectEval("browser || vm", true);
      _expectEval("browser || browser", false);
    });

    test("and", () {
      _expectEval("vm && vm", true);
      _expectEval("vm && browser", false);
      _expectEval("browser && vm", false);
      _expectEval("browser && browser", false);
    });

    test("not", () {
      _expectEval("!vm", false);
      _expectEval("!browser", true);
    });
  });

  group("baseline variable:", () {
    test("vm", () {
      _expectEval("vm", true, platform: TestPlatform.vm);
      _expectEval("vm", false, platform: TestPlatform.chrome);
    });

    test("chrome", () {
      _expectEval("chrome", true, platform: TestPlatform.chrome);
      _expectEval("chrome", false, platform: TestPlatform.vm);
    });

    test("windows", () {
      _expectEval("windows", true, os: OperatingSystem.windows);
      _expectEval("windows", false, os: OperatingSystem.linux);
      _expectEval("windows", false, os: OperatingSystem.none);
    });

    test("mac-os", () {
      _expectEval("mac-os", true, os: OperatingSystem.macOS);
      _expectEval("mac-os", false, os: OperatingSystem.linux);
      _expectEval("mac-os", false, os: OperatingSystem.none);
    });

    test("linux", () {
      _expectEval("linux", true, os: OperatingSystem.linux);
      _expectEval("linux", false, os: OperatingSystem.android);
      _expectEval("linux", false, os: OperatingSystem.none);
    });

    test("android", () {
      _expectEval("android", true, os: OperatingSystem.android);
      _expectEval("android", false, os: OperatingSystem.linux);
      _expectEval("android", false, os: OperatingSystem.none);
    });
  });

  group("derived variable:", () {
    test("dart-vm", () {
      _expectEval("dart-vm", true, platform: TestPlatform.vm);
      _expectEval("dart-vm", false, platform: TestPlatform.chrome);
    });

    test("browser", () {
      _expectEval("browser", true, platform: TestPlatform.chrome);
      _expectEval("browser", false, platform: TestPlatform.vm);
    });

    test("js", () {
      _expectEval("js", true, platform: TestPlatform.chrome);
      _expectEval("js", false, platform: TestPlatform.vm);
    });

    test("blink", () {
      _expectEval("blink", true, platform: TestPlatform.chrome);
      _expectEval("blink", false, platform: TestPlatform.vm);
    });

    test("posix", () {
      _expectEval("posix", false, os: OperatingSystem.windows);
      _expectEval("posix", true, os: OperatingSystem.macOS);
      _expectEval("posix", true, os: OperatingSystem.linux);
      _expectEval("posix", true, os: OperatingSystem.android);
      _expectEval("posix", false, os: OperatingSystem.none);
    });
  });
}

/// Asserts that [expression] evaluates to [result] on [platform] and [os].
///
/// [platform] defaults to [TestPlatform.vm]; [os] defaults to the current
/// operating system.
void _expectEval(String expression, bool result, {TestPlatform platform,
    OperatingSystem os}) {

  var reason = 'Expected "$expression" to evaluate to $result';
  if (platform != null && os != null) {
    reason += ' on $platform and $os.';
  } else if (platform != null || os != null) {
    reason += ' on ${platform == null ? os : platform}';
  }

  expect(_eval(expression, platform: platform, os: os), equals(result),
      reason: '$reason.');
}

/// Returns the result of evaluating [expression] on [platform] and [os].
///
/// [platform] defaults to [TestPlatform.vm]; [os] defaults to the current
/// operating system.
bool _eval(String expression, {TestPlatform platform, OperatingSystem os}) {
  if (platform == null) platform = TestPlatform.vm;
  if (os == null) os = OperatingSystem.findByIoName(Platform.operatingSystem);
  var selector = new PlatformSelector.parse(expression);
  return selector.evaluate(platform, os: os);
}
