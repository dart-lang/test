// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:boolean_selector/boolean_selector.dart';
import 'package:source_span/source_span.dart';

import 'operating_system.dart';
import 'test_platform.dart';

/// The set of all valid variable names.
final _validVariables =
    new Set<String>.from(["posix", "dart-vm", "browser", "js", "blink"])
        ..addAll(TestPlatform.all.map((platform) => platform.identifier))
        ..addAll(OperatingSystem.all.map((os) => os.identifier));

/// An expression for selecting certain platforms, including operating systems
/// and browsers.
///
/// This uses the [boolean selector][] syntax.
///
/// [boolean selector]: https://pub.dartlang.org/packages/boolean_selector
class PlatformSelector {
  /// A selector that declares that a test can be run on all platforms.
  static const all = const PlatformSelector._(BooleanSelector.all);

  /// The boolean selector used to implement this selector.
  final BooleanSelector _inner;

  /// Parses [selector].
  ///
  /// This will throw a [SourceSpanFormatException] if the selector is
  /// malformed or if it uses an undefined variable.
  PlatformSelector.parse(String selector)
      : _inner = new BooleanSelector.parse(selector) {
    _inner.validate(_validVariables.contains);
  }

  const PlatformSelector._(this._inner);

  /// Returns whether the selector matches the given [platform] and [os].
  ///
  /// [os] defaults to [OperatingSystem.none].
  bool evaluate(TestPlatform platform, {OperatingSystem os}) {
    os ??= OperatingSystem.none;

    return _inner.evaluate((variable) {
      if (variable == platform.identifier) return true;
      if (variable == os.identifier) return true;
      switch (variable) {
        case "dart-vm": return platform.isDartVM;
        case "browser": return platform.isBrowser;
        case "js": return platform.isJS;
        case "blink": return platform.isBlink;
        case "posix": return os.isPosix;
        default: return false;
      }
    });
  }

  /// Returns a new [PlatformSelector] that matches only platforms matched by
  /// both [this] and [other].
  PlatformSelector intersection(PlatformSelector other) {
    if (other == PlatformSelector.all) return this;
    return new PlatformSelector._(_inner.intersection(other._inner));
  }

  String toString() => _inner.toString();

  bool operator==(other) => other is PlatformSelector && _inner == other._inner;

  int get hashCode => _inner.hashCode;
}
