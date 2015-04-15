// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.metadata;

import '../frontend/timeout.dart';
import 'platform_selector.dart';

/// Metadata for a test or test suite.
///
/// This metadata comes from declarations on the test itself; it doesn't include
/// configuration from the user.
class Metadata {
  /// The selector indicating which platforms the suite supports.
  final PlatformSelector testOn;

  /// The modification to the timeout for the test or suite.
  final Timeout timeout;

  /// Creates new Metadata.
  ///
  /// [testOn] defaults to [PlatformSelector.all].
  Metadata({PlatformSelector testOn, Timeout timeout})
      : testOn = testOn == null ? PlatformSelector.all : testOn,
        timeout = timeout == null ? const Timeout.factor(1) : timeout;

  /// Creates a new Metadata, but with fields parsed from strings where
  /// applicable.
  ///
  /// Throws a [FormatException] if any field is invalid.
  Metadata.parse({String testOn, Timeout timeout})
      : this(
          testOn: testOn == null ? null : new PlatformSelector.parse(testOn),
          timeout: timeout);

  /// Dezerializes the result of [Metadata.serialize] into a new [Metadata].
  Metadata.deserialize(serialized)
      : this.parse(
          testOn: serialized['testOn'],
          timeout: serialized['timeout']['duration'] == null
              ? new Timeout.factor(serialized['timeout']['scaleFactor'])
              : new Timeout(new Duration(
                  microseconds: serialized['timeout']['duration'])));

  /// Return a new [Metadata] that merges [this] with [other].
  ///
  /// If the two [Metadata]s have conflicting properties, [other] wins.
  Metadata merge(Metadata other) =>
      new Metadata(
          testOn: testOn.intersect(other.testOn),
          timeout: timeout.merge(other.timeout));

  /// Serializes [this] into a JSON-safe object that can be deserialized using
  /// [new Metadata.deserialize].
  serialize() => {
    'testOn': testOn == PlatformSelector.all ? null : testOn.toString(),
    'timeout': {
      'duration': timeout.duration == null
          ? null
          : timeout.duration.inMicroseconds,
      'scaleFactor': timeout.scaleFactor
    }
  };
}
