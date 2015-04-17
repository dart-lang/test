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

  /// Whether the test or suite should be skipped.
  final bool skip;

  /// The reason the test or suite should be skipped, if given.
  final String skipReason;

  /// Creates new Metadata.
  ///
  /// [testOn] defaults to [PlatformSelector.all].
  Metadata({PlatformSelector testOn, Timeout timeout, bool skip: false,
          this.skipReason})
      : testOn = testOn == null ? PlatformSelector.all : testOn,
        timeout = timeout == null ? const Timeout.factor(1) : timeout,
        skip = skip;

  /// Creates a new Metadata, but with fields parsed from strings where
  /// applicable.
  ///
  /// Throws a [FormatException] if any field is invalid.
  Metadata.parse({String testOn, Timeout timeout, skip})
      : testOn = testOn == null
            ? PlatformSelector.all
            : new PlatformSelector.parse(testOn),
        timeout = timeout == null ? const Timeout.factor(1) : timeout,
        skip = skip != null && skip != false,
        skipReason = skip is String ? skip : null {
    if (skip != null && skip is! String && skip is! bool) {
      throw new ArgumentError(
          '"skip" must be a String or a bool, was "$skip".');
    }
  }

  /// Dezerializes the result of [Metadata.serialize] into a new [Metadata].
  Metadata.deserialize(serialized)
      : this.parse(
          testOn: serialized['testOn'],
          timeout: serialized['timeout']['duration'] == null
              ? new Timeout.factor(serialized['timeout']['scaleFactor'])
              : new Timeout(new Duration(
                  microseconds: serialized['timeout']['duration'])),
          skip: serialized['skipReason'] == null
              ? serialized['skip']
              : serialized['skipReason']);

  /// Return a new [Metadata] that merges [this] with [other].
  ///
  /// If the two [Metadata]s have conflicting properties, [other] wins.
  Metadata merge(Metadata other) =>
      new Metadata(
          testOn: testOn.intersect(other.testOn),
          timeout: timeout.merge(other.timeout),
          skip: skip || other.skip,
          skipReason: other.skipReason == null ? skipReason : other.skipReason);

  /// Serializes [this] into a JSON-safe object that can be deserialized using
  /// [new Metadata.deserialize].
  serialize() => {
    'testOn': testOn == PlatformSelector.all ? null : testOn.toString(),
    'timeout': {
      'duration': timeout.duration == null
          ? null
          : timeout.duration.inMicroseconds,
      'scaleFactor': timeout.scaleFactor
    },
    'skip': skip,
    'skipReason': skipReason
  };
}
