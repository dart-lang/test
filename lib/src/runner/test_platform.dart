// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): support pluggable platforms.
/// An enum of all platforms on which tests can run.
class TestPlatform {
  /// The command-line Dart VM.
  static const vm = const TestPlatform._("VM", "vm");

  /// Google Chrome.
  static const chrome = const TestPlatform._("Chrome", "chrome");

  /// A list of all instances of [TestPlatform].
  static const all = const [vm, chrome];

  /// Finds a platform by its identifier string.
  ///
  /// If no platform is found, returns `null`.
  static TestPlatform find(String identifier) =>
      all.firstWhere((platform) => platform.identifier == identifier,
          orElse: () => null);

  /// The human-friendly name of the platform.
  final String name;

  /// The identifier used to look up the platform.
  final String identifier;

  const TestPlatform._(this.name, this.identifier);

  String toString() => name;
}
