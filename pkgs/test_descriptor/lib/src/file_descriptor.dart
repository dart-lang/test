// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';

import 'descriptor.dart';
import 'sandbox.dart';
import 'utils.dart';

/// A descriptor describing a single file.
///
/// In addition to the normal descriptor methods, this has [read] and
/// [readAsBytes] methods that allows its contents to be read.
///
/// This may be extended outside this package.
abstract class FileDescriptor extends Descriptor {
  /// Creates a new [FileDescriptor] with [name] and [contents].
  ///
  /// The [contents] may be a `String`, a `List<int>`, or a [Matcher]. If it's a
  /// string, [create] creates a UTF-8 file and [validate] parses the physical
  /// file as UTF-8. If it's a [Matcher], [validate] matches it against the
  /// physical file's contents parsed as UTF-8, and [create], [read], and
  /// [readAsBytes] are unsupported.
  ///
  /// If [contents] isn't passed, [create] creates an empty file and [validate]
  /// verifies that the file is empty.
  ///
  /// To match a [Matcher] against a file's binary contents, use [new
  /// FileDescriptor.binaryMatcher] instead.
  factory FileDescriptor(String name, contents) {
    if (contents is String) return _StringFileDescriptor(name, contents);
    if (contents is List) {
      return _BinaryFileDescriptor(name, contents.cast<int>());
    }
    if (contents == null) return _BinaryFileDescriptor(name, []);
    return _MatcherFileDescriptor(name, contents as Matcher);
  }

  /// Returns a `dart:io` [File] object that refers to this file within
  /// [sandbox].
  File get io => File(p.join(sandbox, name));

  /// Creates a new binary [FileDescriptor] with [name] that matches its binary
  /// contents against [matcher].
  ///
  /// The [create], [read], and [readAsBytes] methods are unsupported for this
  /// descriptor.
  factory FileDescriptor.binaryMatcher(String name, Matcher matcher) =>
      _MatcherFileDescriptor(name, matcher, isBinary: true);

  /// A protected constructor that's only intended for subclasses.
  FileDescriptor.protected(String name) : super(name);

  @override
  Future<void> create([String? parent]) async {
    // Create the stream before we call [File.openWrite] because it may fail
    // fast (e.g. if this is a matcher file).
    var file = File(p.join(parent ?? sandbox, name)).openWrite();
    try {
      await readAsBytes().listen(file.add).asFuture();
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> validate([String? parent]) async {
    var fullPath = p.join(parent ?? sandbox, name);
    var pretty = prettyPath(fullPath);
    if (!(await File(fullPath).exists())) {
      fail('File not found: "$pretty".');
    }

    await _validate(pretty, await File(fullPath).readAsBytes());
  }

  /// Validates that [binaryContents] matches the expected contents of
  /// the descriptor.
  ///
  /// The [prettyPath] is a human-friendly representation of the path to the
  /// descriptor.
  FutureOr<void> _validate(String prettyPath, List<int> binaryContents);

  /// Reads and decodes the contents of this descriptor as a UTF-8 string.
  ///
  /// This isn't supported for matcher descriptors.
  Future<String> read() => utf8.decodeStream(readAsBytes());

  /// Reads the contents of this descriptor as a byte stream.
  ///
  /// This isn't supported for matcher descriptors.
  Stream<List<int>> readAsBytes();

  @override
  String describe() => name;
}

class _BinaryFileDescriptor extends FileDescriptor {
  /// The contents of this descriptor's file.
  final List<int> _contents;

  _BinaryFileDescriptor(String name, this._contents) : super.protected(name);

  @override
  Stream<List<int>> readAsBytes() => Stream.fromIterable([_contents]);

  @override
  Future<void> _validate(String prettPath, List<int> actualContents) async {
    if (const IterableEquality().equals(_contents, actualContents)) return;
    // TODO(nweiz): show a hex dump here if the data is small enough.
    fail('File "$prettPath" didn\'t contain the expected binary data.');
  }
}

class _StringFileDescriptor extends FileDescriptor {
  /// The contents of this descriptor's file.
  final String _contents;

  _StringFileDescriptor(String name, this._contents) : super.protected(name);

  @override
  Future<String> read() async => _contents;

  @override
  Stream<List<int>> readAsBytes() =>
      Stream.fromIterable([utf8.encode(_contents)]);

  @override
  void _validate(String prettyPath, List<int> actualContents) {
    var actualContentsText = utf8.decode(actualContents);
    if (_contents == actualContentsText) return;
    fail(_textMismatchMessage(prettyPath, _contents, actualContentsText));
  }

  String _textMismatchMessage(
      String prettyPath, String expected, String actual) {
    final expectedLines = expected.split('\n');
    final actualLines = actual.split('\n');

    var results = [];

    // Compare them line by line to see which ones match.
    var length = math.max(expectedLines.length, actualLines.length);
    for (var i = 0; i < length; i++) {
      if (i >= actualLines.length) {
        // Missing output.
        results.add('? ${expectedLines[i]}');
      } else if (i >= expectedLines.length) {
        // Unexpected extra output.
        results.add('X ${actualLines[i]}');
      } else {
        var expectedLine = expectedLines[i];
        var actualLine = actualLines[i];

        if (expectedLine != actualLine) {
          // Mismatched lines.
          results.add('X $actualLine');
        } else {
          // Matched lines.
          results.add('${glyph.verticalLine} $actualLine');
        }
      }
    }

    return 'File "$prettyPath" should contain:\n'
        '${addBar(expected)}\n'
        'but actually contained:\n'
        "${results.join('\n')}";
  }
}

class _MatcherFileDescriptor extends FileDescriptor {
  /// The matcher for this descriptor's contents.
  final Matcher _matcher;

  /// Whether [_matcher] should match against the file's string or byte
  /// contents.
  final bool _isBinary;

  _MatcherFileDescriptor(String name, this._matcher, {bool isBinary = false})
      : _isBinary = isBinary,
        super.protected(name);

  @override
  Stream<List<int>> readAsBytes() =>
      throw UnsupportedError("Matcher files can't be created or read.");

  @override
  Future<void> _validate(String prettyPath, List<int> actualContents) async {
    try {
      expect(
          _isBinary ? actualContents : utf8.decode(actualContents), _matcher);
    } on TestFailure catch (error) {
      fail('Invalid contents for file "$prettyPath":\n${error.message}');
    }
  }
}
