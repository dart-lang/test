// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An enum of all compilers that can be used to compile Dart to JavaScript.
class Compiler {
  // When adding new compilers, be sure to update the baseline and derived
  // variable tests in test/backend/platform_selector/evaluate_test.

  /// The dart2js compiler.
  static const dart2js = const Compiler._("dart2js", "dart2js");

  /// The DDC compiler compiled using the build package.
  static const build = const Compiler._("build package", "build", isDdc: true);

  /// Used for platforms where no compiler is used.
  static const none = const Compiler._("none", "none");

  /// A list of all instances of [Compiler] other than [none].
  static const all = const [dart2js, build];

  /// The human-friendly name of the compiler.
  final String name;

  /// The identifier used to look up the compiler.
  final String identifier;

  /// Whether this uses DDC.
  final bool isDdc;

  /// Finds a compiler by its name.
  ///
  /// If no compiler is found, returns `null`.
  static Compiler find(String identifier) =>
      all.firstWhere((compiler) => compiler.identifier == identifier,
          orElse: () => null);

  const Compiler._(this.name, this.identifier, {this.isDdc: false});

  String toString() => name;
}
