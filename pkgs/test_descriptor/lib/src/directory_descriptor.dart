// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'descriptor.dart';
import 'file_descriptor.dart';
import 'sandbox.dart';
import 'utils.dart';

/// A descriptor describing a directory that may contain nested descriptors.
///
/// In addition to the normal descriptor methods, this has a [load] method that
/// allows it to be used as a virtual filesystem.
///
/// This may be extended outside this package.
class DirectoryDescriptor extends Descriptor {
  /// Descriptors for entries in this directory.
  ///
  /// This may be modified.
  final List<Descriptor> contents;

  /// Returns a `dart:io` [Directory] object that refers to this file within
  /// [sandbox].
  Directory get io => Directory(p.join(sandbox, name));

  DirectoryDescriptor(super.name, Iterable<Descriptor> contents)
      : contents = contents.toList();

  /// Creates a directory descriptor named [name] that describes the physical
  /// directory at [path].
  factory DirectoryDescriptor.fromFilesystem(String name, String path) =>
      DirectoryDescriptor(
        name,
        Directory(path).listSync().map((entity) {
          // Ignore hidden files.
          if (p.basename(entity.path).startsWith('.')) return null;

          if (entity is Directory) {
            return DirectoryDescriptor.fromFilesystem(
              p.basename(entity.path),
              entity.path,
            );
          } else if (entity is File) {
            return FileDescriptor(
              p.basename(entity.path),
              entity.readAsBytesSync(),
            );
          }
          // Ignore broken symlinks.
          return null;
        }).whereType<Descriptor>(),
      );

  @override
  Future<void> create([String? parent]) async {
    final fullPath = p.join(parent ?? sandbox, name);
    await Directory(fullPath).create(recursive: true);
    await Future.wait(contents.map((entry) => entry.create(fullPath)));
  }

  @override
  Future<void> validate([String? parent]) async {
    final fullPath = p.join(parent ?? sandbox, name);
    if (!(await Directory(fullPath).exists())) {
      fail('Directory not found: "${prettyPath(fullPath)}".');
    }

    await waitAndReportErrors(
      contents.map((entry) => entry.validate(fullPath)),
    );
  }

  /// Treats this descriptor as a virtual filesystem and loads the binary
  /// contents of the [FileDescriptor] at the given relative [path].
  Stream<List<int>> load(String path) => _load(path);

  /// Implementation of [load], tracks parents through recursive calls.
  Stream<List<int>> _load(String path, [String? parents]) {
    if (!p.url.isWithin('.', path)) {
      throw ArgumentError.value(
        path,
        'path',
        'must be relative and beneath the base URL.',
      );
    }

    return StreamCompleter.fromFuture(
      Future.sync(() {
        final split = p.url.split(p.url.normalize(path));
        final file = split.length == 1;
        final matchingEntries = contents
            .where(
              (entry) =>
                  entry.name == split.first &&
                  (file
                      ? entry is FileDescriptor
                      : entry is DirectoryDescriptor),
            )
            .toList();

        final type = file ? 'file' : 'directory';
        final parentsAndSelf =
            parents == null ? name : p.url.join(parents, name);
        if (matchingEntries.isEmpty) {
          fail(
              'Couldn\'t find a $type descriptor named "${split.first}" within '
              '"$parentsAndSelf".');
        } else if (matchingEntries.length > 1) {
          fail('Found multiple $type descriptors named "${split.first}" within '
              '"$parentsAndSelf".');
        } else {
          final remainingPath = split.sublist(1);
          if (remainingPath.isEmpty) {
            return (matchingEntries.first as FileDescriptor).readAsBytes();
          } else {
            return (matchingEntries.first as DirectoryDescriptor)
                ._load(p.url.joinAll(remainingPath), parentsAndSelf);
          }
        }
      }),
    );
  }

  @override
  String describe() => describeDirectory(name, contents);
}
