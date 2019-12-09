// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'src/archive_descriptor.dart';
import 'src/descriptor.dart';
import 'src/directory_descriptor.dart';
import 'src/file_descriptor.dart';
import 'src/nothing_descriptor.dart';
import 'src/pattern_descriptor.dart';
import 'src/sandbox.dart';

export 'src/archive_descriptor.dart';
export 'src/descriptor.dart';
export 'src/directory_descriptor.dart';
export 'src/file_descriptor.dart';
export 'src/nothing_descriptor.dart';
export 'src/pattern_descriptor.dart';
export 'src/sandbox.dart' show sandbox;

/// Creates a new [FileDescriptor] with [name] and [contents].
///
/// The [contents] may be a `String`, a `List<int>`, or a [Matcher]. If it's a
/// string, [Descriptor.create] creates a UTF-8 file and [Descriptor.validate]
/// parses the physical file as UTF-8. If it's a [Matcher],
/// [Descriptor.validate] matches it against the physical file's contents parsed
/// as UTF-8, and [Descriptor.create] is unsupported.
///
/// If [contents] isn't passed, [Descriptor.create] creates an empty file and
/// [Descriptor.validate] verifies that the file is empty.
///
/// To match a [Matcher] against a file's binary contents, use [new
/// FileDescriptor.binaryMatcher] instead.
FileDescriptor file(String name, [contents]) => FileDescriptor(name, contents);

/// Creates a new [DirectoryDescriptor] descriptor with [name] and [contents].
///
/// [Descriptor.validate] requires that all descriptors in [contents] match
/// children of the physical diretory, but it *doesn't* require that no other
/// children exist. To ensure that a particular child doesn't exist, use
/// [nothing].
DirectoryDescriptor dir(String name, [Iterable<Descriptor> contents]) =>
    DirectoryDescriptor(name, contents ?? <Descriptor>[]);

/// Creates a new [NothingDescriptor] descriptor that asserts that no entry
/// named [name] exists.
///
/// [Descriptor.create] does nothing for this descriptor.
NothingDescriptor nothing(String name) => NothingDescriptor(name);

/// Creates a new [PatternDescriptor] descriptor that asserts than an entry with
/// a name matching [pattern] exists, and matches the [Descriptor] returned
/// by [child].
///
/// The [child] callback is passed the basename of each entry matching [name].
/// It returns a descriptor that should match that entry. It's valid for
/// multiple entries to match [name] as long as only one of them matches
/// [child].
///
/// [Descriptor.create] is not supported for this descriptor.
PatternDescriptor pattern(
        Pattern name, Descriptor Function(String basename) child) =>
    PatternDescriptor(name, child);

/// A convenience method for creating a [PatternDescriptor] descriptor that
/// constructs a [FileDescriptor] descriptor.
PatternDescriptor filePattern(Pattern name, [contents]) =>
    pattern(name, (realName) => file(realName, contents));

/// A convenience method for creating a [PatternDescriptor] descriptor that
/// constructs a [DirectoryDescriptor] descriptor.
PatternDescriptor dirPattern(Pattern name, [Iterable<Descriptor> contents]) =>
    pattern(name, (realName) => dir(realName, contents));

/// Creates a new [ArchiveDescriptor] with [name] and [contents].
///
/// [Descriptor.create] creates an archive with the given files and directories
/// within it, and [Descriptor.validate] validates that the archive contains the
/// given contents. It *doesn't* require that no other children exist. To ensure
/// that a particular child doesn't exist, use [nothing].
///
/// The type of the archive is determined by [name]'s file extension. It
/// supports `.zip`, `.tar`, `.tar.gz`/`.tar.gzip`/`.tgz`, and
/// `.tar.bz2`/`.tar.bzip2` files.
ArchiveDescriptor archive(String name, [Iterable<Descriptor> contents]) =>
    ArchiveDescriptor(name, contents ?? []);

/// Returns [path] within the [sandbox] directory.
String path(String path) => p.join(sandbox, path);
