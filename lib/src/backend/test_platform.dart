// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): support pluggable platforms.
/// An enum of all platforms on which tests can run.
class TestPlatform {
  // When adding new platforms, be sure to update the baseline and derived
  // variable tests in test/backend/platform_selector/evaluate_test.

  /// The command-line Dart VM.
  static const TestPlatform vm =
      const TestPlatform._("VM", "vm", isDartVM: true, isHeadless: true);

  /// Dartium.
  static const TestPlatform dartium = const TestPlatform._("Dartium", "dartium",
      isBrowser: true, isBlink: true, isDartVM: true);

  /// Dartium content shell.
  static const TestPlatform contentShell = const TestPlatform._(
      "Dartium Content Shell", "content-shell",
      isBrowser: true, isBlink: true, isDartVM: true, isHeadless: true);

  /// Google Chrome.
  static const TestPlatform chrome = const TestPlatform._("Chrome", "chrome",
      isBrowser: true, isJS: true, isBlink: true);

  /// PhantomJS.
  static const TestPlatform phantomJS = const TestPlatform._(
      "PhantomJS", "phantomjs",
      isBrowser: true, isJS: true, isBlink: true, isHeadless: true);

  /// Mozilla Firefox.
  static const TestPlatform firefox = const TestPlatform._("Firefox", "firefox",
      isBrowser: true, isJS: true);

  /// Apple Safari.
  static const TestPlatform safari = const TestPlatform._("Safari", "safari",
      isBrowser: true, isJS: true);

  /// Microsoft Internet Explorer.
  static const TestPlatform internetExplorer = const TestPlatform._(
      "Internet Explorer", "ie",
      isBrowser: true, isJS: true);

  /// A list of all instances of [TestPlatform].
  static const List<TestPlatform> all = const [
    vm,
    dartium,
    contentShell,
    chrome,
    phantomJS,
    firefox,
    safari,
    internetExplorer
  ];

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

  /// Whether this platform runs the Dart VM in any capacity.
  final bool isDartVM;

  /// Whether this platform is a browser.
  final bool isBrowser;

  /// Whether this platform runs Dart compiled to JavaScript.
  final bool isJS;

  /// Whether this platform uses the Blink rendering engine.
  final bool isBlink;

  /// Whether this platform has no visible window.
  final bool isHeadless;

  const TestPlatform._(this.name, this.identifier, {this.isDartVM: false,
      this.isBrowser: false, this.isJS: false, this.isBlink: false,
      this.isHeadless: false});

  String toString() => name;
}
