// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

/// A hook configured to run before or after matching test suites execute.
final class Hook {
  /// The path to the Dart script to execute.
  final String script;

  /// The arguments to pass to the Dart [script].
  final List<String> args;

  Hook(this.script, [this.args = const []]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hook &&
          script == other.script &&
          const ListEquality<String>().equals(args, other.args);

  @override
  int get hashCode =>
      Object.hash(script, const ListEquality<String>().hash(args));
}

typedef PreRunHook = Hook;
typedef PostRunHook = Hook;
