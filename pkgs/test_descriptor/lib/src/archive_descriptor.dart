// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:async/async.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'descriptor.dart';
import 'directory_descriptor.dart';
import 'file_descriptor.dart';
import 'sandbox.dart';
import 'utils.dart';

/// A [Descriptor] describing files in a Tar or Zip archive.
///
/// The format is determined by the descriptor's file extension.
@sealed
class ArchiveDescriptor extends Descriptor implements FileDescriptor {
  /// Descriptors for entries in this archive.
  final List<Descriptor> contents;

  /// Returns a `package:archive` [Archive] object that contains the contents of
  /// this file.
  Future<Archive> get archive async {
    var archive = Archive();
    (await _files(contents)).forEach(archive.addFile);
    return archive;
  }

  File get io => File(p.join(sandbox, name));

  /// Returns [ArchiveFile]s for each file in [descriptors].
  ///
  /// If [parent] is passed, it's used as the parent directory for filenames.
  Future<Iterable<ArchiveFile>> _files(Iterable<Descriptor> descriptors,
      [String parent]) async {
    return (await waitAndReportErrors(descriptors.map((descriptor) async {
      var fullName =
          parent == null ? descriptor.name : "$parent/${descriptor.name}";

      if (descriptor is FileDescriptor) {
        var bytes = await collectBytes(descriptor.readAsBytes());
        return [
          ArchiveFile(fullName, bytes.length, bytes)
            // Setting the mode and mod time are necessary to work around
            // brendan-duncan/archive#76.
            ..mode = 428
            ..lastModTime = DateTime.now().millisecondsSinceEpoch ~/ 1000
        ];
      } else if (descriptor is DirectoryDescriptor) {
        return await _files(descriptor.contents, fullName);
      } else {
        throw UnsupportedError(
            "An archive can only be created from FileDescriptors and "
            "DirectoryDescriptors.");
      }
    })))
        .expand((files) => files);
  }

  ArchiveDescriptor(String name, Iterable<Descriptor> contents)
      : contents = List.unmodifiable(contents),
        super(name);

  Future create([String parent]) async {
    var path = p.join(parent ?? sandbox, name);
    var file = File(path).openWrite();
    try {
      try {
        await readAsBytes().listen(file.add).asFuture();
      } finally {
        await file.close();
      }
    } catch (_) {
      await File(path).delete();
      rethrow;
    }
  }

  Future<String> read() async => throw UnsupportedError(
      "ArchiveDescriptor.read() is not supported. Use Archive.readAsBytes() "
      "instead.");

  Stream<List<int>> readAsBytes() => Stream.fromFuture(() async {
        return _encodeFunction()(await archive);
      }());

  Future<void> validate([String parent]) async {
    // Access this first so we eaerly throw an error for a path with an invalid
    // extension.
    var decoder = _decodeFunction();

    var fullPath = p.join(parent ?? sandbox, name);
    var pretty = prettyPath(fullPath);
    if (!(await File(fullPath).exists())) {
      fail('File not found: "$pretty".');
    }

    var bytes = await File(fullPath).readAsBytes();
    Archive archive;
    try {
      archive = decoder(bytes);
    } catch (_) {
      // Catch every error to work around brendan-duncan/archive#77.
      fail('File "$pretty" is not a valid archive.');
    }

    // Because validators expect to validate against a real filesystem, we have
    // to extract the archive to a temp directory and run validation on that.
    var tempDir = await Directory.systemTemp
        .createTempSync('dart_test_')
        .resolveSymbolicLinks();

    try {
      await waitAndReportErrors(archive.files.map((file) async {
        var path = p.join(tempDir, file.name);
        await Directory(p.dirname(path)).create(recursive: true);
        await File(path).writeAsBytes(file.content as List<int>);
      }));

      await waitAndReportErrors(contents.map((entry) async {
        try {
          await entry.validate(tempDir);
        } on TestFailure catch (error) {
          // Replace the temporary directory with the path to the archive to
          // make the error more user-friendly.
          fail(error.message.replaceAll(tempDir, pretty));
        }
      }));
    } finally {
      await Directory(tempDir).delete(recursive: true);
    }
  }

  /// Returns the function to use to encode this file to binary, based on its
  /// [name].
  List<int> Function(Archive) _encodeFunction() {
    if (name.endsWith(".zip")) {
      return ZipEncoder().encode;
    } else if (name.endsWith(".tar")) {
      return TarEncoder().encode;
    } else if (name.endsWith(".tar.gz") ||
        name.endsWith(".tar.gzip") ||
        name.endsWith(".tgz")) {
      return (archive) => GZipEncoder().encode(TarEncoder().encode(archive));
    } else if (name.endsWith(".tar.bz2") || name.endsWith(".tar.bzip2")) {
      return (archive) => BZip2Encoder().encode(TarEncoder().encode(archive));
    } else {
      throw UnsupportedError("Unknown file format $name.");
    }
  }

  /// Returns the function to use to decode this file from binary, based on its
  /// [name].
  Archive Function(List<int>) _decodeFunction() {
    if (name.endsWith(".zip")) {
      return ZipDecoder().decodeBytes;
    } else if (name.endsWith(".tar")) {
      return TarDecoder().decodeBytes;
    } else if (name.endsWith(".tar.gz") ||
        name.endsWith(".tar.gzip") ||
        name.endsWith(".tgz")) {
      return (archive) =>
          TarDecoder().decodeBytes(GZipDecoder().decodeBytes(archive));
    } else if (name.endsWith(".tar.bz2") || name.endsWith(".tar.bzip2")) {
      return (archive) =>
          TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(archive));
    } else {
      throw UnsupportedError("Unknown file format $name.");
    }
  }

  String describe() => describeDirectory(name, contents);
}
