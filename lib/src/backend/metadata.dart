// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.metadata;

import 'dart:collection';

import '../backend/operating_system.dart';
import '../backend/test_platform.dart';
import '../frontend/skip.dart';
import '../frontend/timeout.dart';
import '../utils.dart';
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

  /// Whether to use verbose stack traces.
  final bool verboseTrace;

  /// The reason the test or suite should be skipped, if given.
  final String skipReason;

  /// Platform-specific metadata.
  ///
  /// Each key identifies a platform, and its value identifies the specific
  /// metadata for that platform. These can be applied by calling [forPlatform].
  final Map<PlatformSelector, Metadata> onPlatform;

  /// Parses a user-provided map into the value for [onPlatform].
  static Map<PlatformSelector, Metadata> _parseOnPlatform(
      Map<String, dynamic> onPlatform) {
    if (onPlatform == null) return {};

    var result = {};
    onPlatform.forEach((platform, metadata) {
      if (metadata is Timeout || metadata is Skip) {
        metadata = [metadata];
      } else if (metadata is! List) {
        throw new ArgumentError('Metadata for platform "$platform" must be a '
            'Timeout, Skip, or List of those; was "$metadata".');
      }

      var selector = new PlatformSelector.parse(platform);

      var timeout;
      var skip;
      for (var metadatum in metadata) {
        if (metadatum is Timeout) {
          if (timeout != null) {
            throw new ArgumentError('Only a single Timeout may be declared for '
                '"$platform".');
          }

          timeout = metadatum;
        } else if (metadatum is Skip) {
          if (skip != null) {
            throw new ArgumentError('Only a single Skip may be declared for '
                '"$platform".');
          }

          skip = metadatum.reason == null ? true : metadatum.reason;
        } else {
          throw new ArgumentError('Metadata for platform "$platform" must be a '
              'Timeout, Skip, or List of those; was "$metadata".');
        }
      }

      result[selector] = new Metadata.parse(timeout: timeout, skip: skip);
    });
    return result;
  }

  /// Creates new Metadata.
  ///
  /// [testOn] defaults to [PlatformSelector.all].
  Metadata({PlatformSelector testOn, Timeout timeout, bool skip: false,
          this.verboseTrace: false, this.skipReason,
          Map<PlatformSelector, Metadata> onPlatform})
      : testOn = testOn == null ? PlatformSelector.all : testOn,
        timeout = timeout == null ? const Timeout.factor(1) : timeout,
        skip = skip,
        onPlatform = onPlatform == null
            ? const {}
            : new UnmodifiableMapView(onPlatform);

  /// Creates a new Metadata, but with fields parsed from caller-friendly values
  /// where applicable.
  ///
  /// Throws a [FormatException] if any field is invalid.
  Metadata.parse({String testOn, Timeout timeout, skip,
          this.verboseTrace: false, Map<String, dynamic> onPlatform})
      : testOn = testOn == null
            ? PlatformSelector.all
            : new PlatformSelector.parse(testOn),
        timeout = timeout == null ? const Timeout.factor(1) : timeout,
        skip = skip != null && skip != false,
        skipReason = skip is String ? skip : null,
        onPlatform = _parseOnPlatform(onPlatform) {
    if (skip != null && skip is! String && skip is! bool) {
      throw new ArgumentError(
          '"skip" must be a String or a bool, was "$skip".');
    }
  }

  /// Dezerializes the result of [Metadata.serialize] into a new [Metadata].
  Metadata.deserialize(serialized)
      : testOn = serialized['testOn'] == null
            ? PlatformSelector.all
            : new PlatformSelector.parse(serialized['testOn']),
        timeout = serialized['timeout']['duration'] == null
            ? new Timeout.factor(serialized['timeout']['scaleFactor'])
            : new Timeout(new Duration(
                microseconds: serialized['timeout']['duration'])),
        skip = serialized['skip'],
        skipReason = serialized['skipReason'],
        verboseTrace = serialized['verboseTrace'],
        onPlatform = new Map.fromIterable(serialized['onPlatform'],
            key: (pair) => new PlatformSelector.parse(pair.first),
            value: (pair) => new Metadata.deserialize(pair.last));

  /// Return a new [Metadata] that merges [this] with [other].
  ///
  /// If the two [Metadata]s have conflicting properties, [other] wins.
  Metadata merge(Metadata other) =>
      new Metadata(
          testOn: testOn.intersect(other.testOn),
          timeout: timeout.merge(other.timeout),
          skip: skip || other.skip,
          verboseTrace: verboseTrace || other.verboseTrace,
          skipReason: other.skipReason == null ? skipReason : other.skipReason,
          onPlatform: mergeMaps(onPlatform, other.onPlatform));

  /// Returns a copy of [this] with the given fields changed.
  Metadata change({PlatformSelector testOn, Timeout timeout, bool skip,
      bool verboseTrace, String skipReason,
      Map<PlatformSelector, Metadata> onPlatform}) {
    if (testOn == null) testOn = this.testOn;
    if (timeout == null) timeout = this.timeout;
    if (skip == null) skip = this.skip;
    if (verboseTrace == null) verboseTrace = this.verboseTrace;
    if (skipReason == null) skipReason = this.skipReason;
    if (onPlatform == null) onPlatform = this.onPlatform;
    return new Metadata(testOn: testOn, timeout: timeout, skip: skip,
        verboseTrace: verboseTrace, skipReason: skipReason,
        onPlatform: onPlatform);
  }

  /// Returns a copy of [this] with all platform-specific metadata from
  /// [onPlatform] resolved.
  Metadata forPlatform(TestPlatform platform, {OperatingSystem os}) {
    if (onPlatform.isEmpty) return this;

    var metadata = this;
    onPlatform.forEach((platformSelector, platformMetadata) {
      if (!platformSelector.evaluate(platform, os: os)) return;
      metadata = metadata.merge(platformMetadata);
    });
    return metadata.change(onPlatform: {});
  }

  /// Serializes [this] into a JSON-safe object that can be deserialized using
  /// [new Metadata.deserialize].
  serialize() {
    // Make this a list to guarantee that the order is preserved.
    var serializedOnPlatform = [];
    onPlatform.forEach((key, value) {
      serializedOnPlatform.add([key.toString(), value.serialize()]);
    });

    return {
      'testOn': testOn == PlatformSelector.all ? null : testOn.toString(),
      'timeout': {
        'duration': timeout.duration == null
            ? null
            : timeout.duration.inMicroseconds,
        'scaleFactor': timeout.scaleFactor
      },
      'skip': skip,
      'skipReason': skipReason,
      'verboseTrace': verboseTrace,
      'onPlatform': serializedOnPlatform
    };
  }
}
