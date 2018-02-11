// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'compiler.dart';
import 'group.dart';
import 'metadata.dart';
import 'operating_system.dart';
import 'test.dart';
import 'test_platform.dart';

/// A test suite.
///
/// A test suite is a set of tests that are intended to be run together and that
/// share default configuration.
class Suite {
  /// The platform on which the suite is running, or `null` if that platform is
  /// unknown.
  final TestPlatform platform;

  /// The operating system on which the suite is running, or `null` if that
  /// operating system is unknown.
  ///
  /// This will always be `null` if [platform] is `null`.
  final OperatingSystem os;

  /// The compiler with which the suite was compiled running, or `null` if that
  /// compiler is unknown.
  ///
  /// This will always be `null` if [platform] is `null`.
  final Compiler compiler;

  /// The path to the Dart test suite, or `null` if that path is unknown.
  final String path;

  /// The metadata associated with this test suite.
  ///
  /// This is a shortcut for [group.metadata].
  Metadata get metadata => group.metadata;

  /// The top-level group for this test suite.
  final Group group;

  /// Creates a new suite containing [entires].
  ///
  /// If [platform], [os] and/or [compiler] are passed, [group] is filtered to
  /// match that platform information.
  ///
  /// If [os] or [compiler] is passed without [platform], throws an
  /// [ArgumentError].
  Suite(Group group,
      {this.path, TestPlatform platform, OperatingSystem os, Compiler compiler})
      : platform = platform,
        os = os,
        compiler = compiler,
        group = _filterGroup(group, platform, os, compiler);

  /// Returns [entries] filtered according to [platform], [os], and [compiler].
  ///
  /// Gracefully handles [platform] being null.
  static Group _filterGroup(Group group, TestPlatform platform,
      OperatingSystem os, Compiler compiler) {
    if (platform == null) {
      if (os != null) {
        throw new ArgumentError.value(
            os, "os", "must be null if platform is null");
      } else if (compiler != null) {
        throw new ArgumentError.value(
            compiler, "compiler", "must be null if platform is null");
      }
    }

    if (platform == null) return group;
    var filtered = group.forPlatform(platform, os: os, compiler: compiler);
    if (filtered != null) return filtered;
    return new Group.root([], metadata: group.metadata);
  }

  /// Returns a new suite with all tests matching [test] removed.
  ///
  /// Unlike [GroupEntry.filter], this never returns `null`. If all entries are
  /// filtered out, it returns an empty suite.
  Suite filter(bool callback(Test test)) {
    var filtered = group.filter(callback);
    if (filtered == null) filtered = new Group.root([], metadata: metadata);
    return new Suite(filtered,
        platform: platform, os: os, compiler: compiler, path: path);
  }
}
