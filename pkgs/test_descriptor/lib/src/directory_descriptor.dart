// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
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

  DirectoryDescriptor(String name, Iterable<Descriptor> contents)
      : contents = contents.toList(),
        super(name);

  /// Creates a directory descriptor named [name] that describes the physical
  /// directory at [path].
  factory DirectoryDescriptor.fromFilesystem(String name, String path) {
    return new DirectoryDescriptor(name,
        new Directory(path).listSync().map((entity) {
      // Ignore hidden files.
      if (p.basename(entity.path).startsWith(".")) return null;

      if (entity is Directory) {
        return new DirectoryDescriptor.fromFilesystem(
            p.basename(entity.path), entity.path);
      } else if (entity is File) {
        return new FileDescriptor(
            p.basename(entity.path), entity.readAsBytesSync());
      }
      // Ignore broken symlinks.
    }).where((path) => path != null));
  }

  Future create([String parent]) async {
    var fullPath = p.join(parent ?? sandbox, name);
    await new Directory(fullPath).create(recursive: true);
    await Future.wait(contents.map((entry) => entry.create(fullPath)));
  }

  Future validate([String parent]) async {
    var fullPath = p.join(parent ?? sandbox, name);
    if (!(await new Directory(fullPath).exists())) {
      fail('Directory not found: "${prettyPath(fullPath)}".');
    }

    await waitAndReportErrors(
        contents.map((entry) => entry.validate(fullPath)));
  }

  /// Treats this descriptor as a virtual filesystem and loads the binary
  /// contents of the [FileDescriptor] at the given relative [url], which may be
  /// a [Uri] or a [String].
  ///
  /// The [parent] parameter should only be passed by subclasses of
  /// [DirectoryDescriptor] that are recursively calling [load]. It's the
  /// URL-format path of the directories that have been loaded so far.
  Stream<List<int>> load(url, [String parents]) {
    String path;
    if (url is String) {
      path = url;
    } else if (url is Uri) {
      path = url.toString();
    } else {
      throw new ArgumentError.value(url, "url", "must be a Uri or a String.");
    }

    if (!p.url.isWithin('.', path)) {
      throw new ArgumentError.value(
          url, "url", "must be relative and beneath the base URL.");
    }

    return StreamCompleter.fromFuture(new Future.sync(() {
      var split = p.url.split(p.url.normalize(path));
      var file = split.length == 1;
      var matchingEntries = contents.where((entry) {
        return entry.name == split.first &&
            file
                ? entry is FileDescriptor
                : entry is DirectoryDescriptor;
      }).toList();

      var type = file ? 'file' : 'directory';
      var parentsAndSelf = parents == null ? name : p.url.join(parents, name);
      if (matchingEntries.isEmpty) {
        fail('Couldn\'t find a $type descriptor named "${split.first}" within '
             '"$parentsAndSelf".');
      } else if (matchingEntries.length > 1) {
        fail('Found multiple $type descriptors named "${split.first}" within '
             '"$parentsAndSelf".');
      } else {
        var remainingPath = split.sublist(1);
        if (remainingPath.isEmpty) {
          return (matchingEntries.first as FileDescriptor).readAsBytes();
        } else {
          return (matchingEntries.first as DirectoryDescriptor)
              .load(p.url.joinAll(remainingPath), parentsAndSelf);
        }
      }
    }));
  }

  String describe() {
    if (contents.isEmpty) return name;

    var buffer = new StringBuffer();
    buffer.writeln(name);
    for (var entry in contents.take(contents.length - 1)) {
      var entryString = prefixLines(
          entry.describe(), '${glyph.verticalLine}   ',
          first: '${glyph.teeRight}${glyph.horizontalLine}'
              '${glyph.horizontalLine} ');
      buffer.writeln(entryString);
    }

    var lastEntryString = prefixLines(contents.last.describe(), '    ',
        first: '${glyph.bottomLeftCorner}${glyph.horizontalLine}'
              '${glyph.horizontalLine} ');
    buffer.write(lastEntryString);
    return buffer.toString();
  }
}
