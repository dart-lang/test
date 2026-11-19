// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../context.dart';

extension DateTimeChecks on Subject<DateTime> {
  /// Expects that this value occurs at the same moment in time as [other].
  ///
  /// Unlike `equals`, which also compares whether each value is in UTC or
  /// in the local time zone, this only compares the moment in time. See
  /// [DateTime.isAtSameMomentAs].
  ///
  /// {@example /example/date_time/date_time/is_at_same_moment_as.dart}
  void isAtSameMomentAs(DateTime other) {
    context.expect(
      () => prefixFirst('is at the same moment as ', literal(other)),
      (actual) {
        if (actual.isAtSameMomentAs(other)) return null;
        final difference = actual.difference(other);
        return Rejection(
          which: [
            'is <${difference.abs()}> '
                '${difference.isNegative ? 'before' : 'after'}',
          ],
        );
      },
    );
  }

  /// Expects that the difference between this value and [other] is less than
  /// or equal to [delta].
  ///
  /// {@example /example/date_time/date_time/is_close_to.dart}
  void isCloseTo(DateTime other, Duration delta) {
    context.expect(() => ['is within <$delta> of <$other>'], (actual) {
      final difference = actual.difference(other).abs();
      if (difference <= delta) return null;
      return Rejection(which: ['differs by <$difference>']);
    });
  }

  /// Expects that [DateTime.isUtc] is true.
  ///
  /// {@example /example/date_time/date_time/is_utc.dart}
  void get isUtc {
    context.expect(
      () => ['is in UTC'],
      predicateNoun: () => 'a UTC time',
      (actual) => actual.isUtc ? null : Rejection(which: ['is local']),
    );
  }

  /// Expects that [DateTime.isUtc] is false.
  ///
  /// {@example /example/date_time/date_time/is_local.dart}
  void get isLocal {
    context.expect(
      () => ['is in the local time zone'],
      predicateNoun: () => 'a local time',
      (actual) => actual.isUtc ? Rejection(which: ['is in UTC']) : null,
    );
  }
}

extension DurationChecks on Subject<Duration> {
  /// Expects that the difference between this value and [other] is less than
  /// or equal to [delta].
  ///
  /// {@example /example/date_time/duration/is_close_to.dart}
  void isCloseTo(Duration other, Duration delta) {
    context.expect(() => ['is within <$delta> of <$other>'], (actual) {
      final difference = (other - actual).abs();
      if (difference <= delta) return null;
      return Rejection(which: ['differs by <$difference>']);
    });
  }
}
