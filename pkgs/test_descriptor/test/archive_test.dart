// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  group("create()", () {
    test("creates an empty archive", () async {
      await d.archive("test.tar").create();

      var archive =
          TarDecoder().decodeBytes(File(d.path("test.tar")).readAsBytesSync());
      expect(archive.files, isEmpty);
    });

    test("creates an archive with files", () async {
      await d.archive("test.tar", [
        d.file("file1.txt", "contents 1"),
        d.file("file2.txt", "contents 2")
      ]).create();

      var files = TarDecoder()
          .decodeBytes(File(d.path("test.tar")).readAsBytesSync())
          .files;
      expect(files.length, equals(2));
      _expectFile(files[0], "file1.txt", "contents 1");
      _expectFile(files[1], "file2.txt", "contents 2");
    });

    test("creates an archive with files in a directory", () async {
      await d.archive("test.tar", [
        d.dir("dir", [
          d.file("file1.txt", "contents 1"),
          d.file("file2.txt", "contents 2")
        ])
      ]).create();

      var files = TarDecoder()
          .decodeBytes(File(d.path("test.tar")).readAsBytesSync())
          .files;
      expect(files.length, equals(2));
      _expectFile(files[0], "dir/file1.txt", "contents 1");
      _expectFile(files[1], "dir/file2.txt", "contents 2");
    });

    test("creates an archive with files in a nested directory", () async {
      await d.archive("test.tar", [
        d.dir("dir", [
          d.dir("subdir", [
            d.file("file1.txt", "contents 1"),
            d.file("file2.txt", "contents 2")
          ])
        ])
      ]).create();

      var files = TarDecoder()
          .decodeBytes(File(d.path("test.tar")).readAsBytesSync())
          .files;
      expect(files.length, equals(2));
      _expectFile(files[0], "dir/subdir/file1.txt", "contents 1");
      _expectFile(files[1], "dir/subdir/file2.txt", "contents 2");
    });

    group("creates a file in", () {
      test("zip format", () async {
        await d.archive("test.zip", [d.file("file.txt", "contents")]).create();

        var archive = ZipDecoder()
            .decodeBytes(File(d.path("test.zip")).readAsBytesSync());
        _expectFile(archive.files.single, "file.txt", "contents");
      });

      group("gzip tar format", () {
        for (var extension in [".tar.gz", ".tar.gzip", ".tgz"]) {
          test("with $extension", () async {
            await d.archive(
                "test$extension", [d.file("file.txt", "contents")]).create();

            var archive = TarDecoder().decodeBytes(GZipDecoder()
                .decodeBytes(File(d.path("test$extension")).readAsBytesSync()));
            _expectFile(archive.files.single, "file.txt", "contents");
          });
        }
      });

      group("bzip2 tar format", () {
        for (var extension in [".tar.bz2", ".tar.bzip2"]) {
          test("with $extension", () async {
            await d.archive(
                "test$extension", [d.file("file.txt", "contents")]).create();

            var archive = TarDecoder().decodeBytes(BZip2Decoder()
                .decodeBytes(File(d.path("test$extension")).readAsBytesSync()));
            _expectFile(archive.files.single, "file.txt", "contents");
          });
        }
      });
    });

    group("gracefully rejects", () {
      test("an uncreatable descriptor", () async {
        await expectLater(
            d.archive("test.tar", [d.filePattern(RegExp(r"^foo-"))]).create(),
            throwsUnsupportedError);
        await d.nothing("test.tar").validate();
      });

      test("a non-file non-directory descriptor", () async {
        await expectLater(
            d.archive("test.tar", [d.nothing("file.txt")]).create(),
            throwsUnsupportedError);
        await d.nothing("test.tar").validate();
      });

      test("an unknown file extension", () async {
        await expectLater(
            d.archive("test.asdf", [d.nothing("file.txt")]).create(),
            throwsUnsupportedError);
      });
    });
  });

  group("validate()", () {
    group("with an empty archive", () {
      test("succeeds if an empty archive exists", () async {
        File(d.path("test.tar"))
            .writeAsBytesSync(TarEncoder().encode(Archive()));
        await d.archive("test.tar").validate();
      });

      test("succeeds if a non-empty archive exists", () async {
        File(d.path("test.tar")).writeAsBytesSync(
            TarEncoder().encode(Archive()..addFile(_file("file.txt"))));
        await d.archive("test.tar").validate();
      });

      test("fails if no archive exists", () {
        expect(d.archive("test.tar").validate(),
            throwsA(toString(startsWith('File not found: "test.tar".'))));
      });

      test("fails if an invalid archive exists", () {
        d.file("test.tar", "not a valid tar file").create();
        expect(
            d.archive("test.tar").validate(),
            throwsA(toString(
                startsWith('File "test.tar" is not a valid archive.'))));
      });
    });

    test("succeeds if an archive contains a matching file", () async {
      File(d.path("test.tar")).writeAsBytesSync(TarEncoder()
          .encode(Archive()..addFile(_file("file.txt", "contents"))));
      await d.archive("test.tar", [d.file("file.txt", "contents")]).validate();
    });

    test("fails if an archive doesn't contain a file", () async {
      File(d.path("test.tar")).writeAsBytesSync(TarEncoder().encode(Archive()));
      expect(
          d.archive("test.tar", [d.file("file.txt", "contents")]).validate(),
          throwsA(
              toString(startsWith('File not found: "test.tar/file.txt".'))));
    });

    test("fails if an archive contains a non-matching file", () async {
      File(d.path("test.tar")).writeAsBytesSync(TarEncoder()
          .encode(Archive()..addFile(_file("file.txt", "wrong contents"))));
      expect(
          d.archive("test.tar", [d.file("file.txt", "contents")]).validate(),
          throwsA(toString(
              startsWith('File "test.tar/file.txt" should contain:'))));
    });

    test("succeeds if an archive contains a file matching a pattern", () async {
      File(d.path("test.tar")).writeAsBytesSync(TarEncoder()
          .encode(Archive()..addFile(_file("file.txt", "contents"))));
      await d.archive("test.tar",
          [d.filePattern(RegExp(r"f..e\.txt"), "contents")]).validate();
    });

    group("validates a file in", () {
      test("zip format", () async {
        File(d.path("test.zip")).writeAsBytesSync(ZipEncoder()
            .encode(Archive()..addFile(_file("file.txt", "contents"))));

        await d
            .archive("test.zip", [d.file("file.txt", "contents")]).validate();
      });

      group("gzip tar format", () {
        for (var extension in [".tar.gz", ".tar.gzip", ".tgz"]) {
          test("with $extension", () async {
            File(d.path("test$extension")).writeAsBytesSync(GZipEncoder()
                .encode(TarEncoder().encode(
                    Archive()..addFile(_file("file.txt", "contents")))));

            await d.archive(
                "test$extension", [d.file("file.txt", "contents")]).validate();
          });
        }
      });

      group("bzip2 tar format", () {
        for (var extension in [".tar.bz2", ".tar.bzip2"]) {
          test("with $extension", () async {
            File(d.path("test$extension")).writeAsBytesSync(BZip2Encoder()
                .encode(TarEncoder().encode(
                    Archive()..addFile(_file("file.txt", "contents")))));

            await d.archive(
                "test$extension", [d.file("file.txt", "contents")]).validate();
          });
        }
      });
    });

    test("gracefully rejects an unknown file format", () {
      expect(d.archive("test.asdf").validate(), throwsUnsupportedError);
    });
  });

  test("read() is unsupported", () {
    expect(d.archive("test.tar").read(), throwsUnsupportedError);
  });

  test("readAsBytes() returns the contents of the archive", () async {
    var descriptor = d.archive("test.tar",
        [d.file("file1.txt", "contents 1"), d.file("file2.txt", "contents 2")]);

    var files = TarDecoder()
        .decodeBytes(await collectBytes(descriptor.readAsBytes()))
        .files;
    expect(files.length, equals(2));
    _expectFile(files[0], "file1.txt", "contents 1");
    _expectFile(files[1], "file2.txt", "contents 2");
  });

  test("archive returns the in-memory contents", () async {
    var archive = await d.archive("test.tar", [
      d.file("file1.txt", "contents 1"),
      d.file("file2.txt", "contents 2")
    ]).archive;

    var files = archive.files;
    expect(files.length, equals(2));
    _expectFile(files[0], "file1.txt", "contents 1");
    _expectFile(files[1], "file2.txt", "contents 2");
  });

  test("io refers to the file within the sandbox", () {
    expect(d.file('test.tar').io.path, equals(p.join(d.sandbox, 'test.tar')));
  });
}

/// Asserts that [file] has the given [name] and [contents].
void _expectFile(ArchiveFile file, String name, String contents) {
  expect(file.name, equals(name));
  expect(utf8.decode(file.content as List<int>), equals(contents));
}

/// Creates an [ArchiveFile] with the given [name] and [contents].
ArchiveFile _file(String name, [String contents]) {
  var bytes = utf8.encode(contents ?? "");
  return ArchiveFile(name, bytes.length, bytes)
    // Setting the mode and mod time are necessary to work around
    // brendan-duncan/archive#76.
    ..mode = 428
    ..lastModTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
