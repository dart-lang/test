// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'descriptor.dart';
import 'sandbox.dart';
import 'utils.dart';

/// A descriptor that matches filesystem entity names by [Pattern] rather than
/// by exact [String].
///
/// This descriptor may only be used for validation.
class PatternDescriptor extends Descriptor {
  /// The [Pattern] this matches filenames against. Note that the pattern must
  /// match the entire basename of the file.
  final Pattern pattern;

  /// The function used to generate the [Descriptor] for filesystem entities
  /// matching [pattern].
  final Descriptor Function(String) _fn;

  PatternDescriptor(this.pattern, Descriptor Function(String basename) child)
      : _fn = child,
        super('$pattern');

  /// Validates that there is some filesystem entity in [parent] that matches
  /// [pattern] and the child entry. This finds all entities in [parent]
  /// matching [pattern], then passes each of their names to `child` provided
  /// in the constructor and validates the result. If exactly one succeeds,
  /// `this` is considered valid.
  @override
  Future<void> validate([String? parent]) async {
    final inSandbox = parent == null;
    parent ??= sandbox;
    final matchingEntries = await Directory(parent)
        .list()
        .map(
          (entry) =>
              entry is File ? entry.resolveSymbolicLinksSync() : entry.path,
        )
        .where((entry) => matchesAll(pattern, p.basename(entry)))
        .toList();
    matchingEntries.sort();

    final location = inSandbox ? 'sandbox' : '"${prettyPath(parent)}"';
    if (matchingEntries.isEmpty) {
      fail('No entries found in $location matching $_patternDescription.');
    }

    final results = await Future.wait(
      matchingEntries
          .map((entry) {
            final basename = p.basename(entry);
            return runZonedGuarded(
                () => Result.capture(
                      Future.sync(() async {
                        await _fn(basename).validate(parent);
                        return basename;
                      }),
                    ), (_, __) {
              // Validate may produce multiple errors, but we ignore all but the
              // first to avoid cluttering the user with many different errors
              // from many different un-matched entries.
            });
          })
          .whereType<Future<Result<String>>>()
          .toList(),
    );

    final successes = results.where((result) => result.isValue).toList();
    if (successes.isEmpty) {
      await waitAndReportErrors(results.map((result) => result.asFuture));
    } else if (successes.length > 1) {
      fail('Multiple valid entries found in $location matching '
          '$_patternDescription:\n'
          '${bullet(successes.map((result) => result.asValue!.value))}');
    }
  }

  @override
  String describe() => 'entry matching $_patternDescription';

  String get _patternDescription {
    if (pattern is String) return '"$pattern"';
    if (pattern is! RegExp) return '$pattern';

    final regExp = pattern as RegExp;
    final flags = StringBuffer();
    if (!regExp.isCaseSensitive) flags.write('i');
    if (regExp.isMultiLine) flags.write('m');
    return '/${regExp.pattern}/$flags';
  }

  @override
  Future<void> create([String? parent]) {
    throw UnsupportedError("Pattern descriptors don't support create().");
  }
}
