// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

/// A hook configured to run before matching test suites execute.
final class PreRunHook {
  /// The command to execute.
  final String command;

  /// The arguments to pass to [command].
  final List<String> args;

  /// An optional teardown hook to run when tests finish.
  final PreRunHook? postRun;

  PreRunHook(this.command, [this.args = const [], this.postRun]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreRunHook &&
          command == other.command &&
          const ListEquality<String>().equals(args, other.args) &&
          postRun == other.postRun;

  @override
  int get hashCode =>
      Object.hash(command, const ListEquality<String>().hash(args), postRun);

  @override
  String toString() => args.isEmpty ? command : '$command ${args.join(' ')}';
}
