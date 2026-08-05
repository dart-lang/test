// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

/// A hook configured to run before or after matching test suites execute.
final class Hook {
  /// The command to execute.
  final String command;

  /// The arguments to pass to [command].
  final List<String> args;

  Hook(this.command, [this.args = const []]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hook &&
          command == other.command &&
          const ListEquality<String>().equals(args, other.args);

  @override
  int get hashCode =>
      Object.hash(command, const ListEquality<String>().hash(args));

  @override
  String toString() => args.isEmpty ? command : '$command ${args.join(' ')}';
}

typedef PreRunHook = Hook;
typedef PostRunHook = Hook;
