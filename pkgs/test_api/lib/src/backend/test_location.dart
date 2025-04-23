// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The location of a test or group.
class TestLocation {
  final Uri uri;
  final int line;
  final int column;

  TestLocation(this.uri, this.line, this.column);

  /// Serializes [this] into a JSON-safe object that can be deserialized using
  /// [TestLocation.deserialize].
  ///
  /// This method is also used to provide the location in the JSON reporter when
  /// a custom location is provided for the test.
  Map<String, dynamic> serialize() {
    return {
      'url': uri.toString(),
      'line': line,
      'column': column,
    };
  }

  /// Deserializes the result of [TestLocation.serialize] into a new [TestLocation].
  TestLocation.deserialize(Map serialized)
      : this(Uri.parse(serialized['url'] as String), serialized['line'] as int,
            serialized['column'] as int);
}
