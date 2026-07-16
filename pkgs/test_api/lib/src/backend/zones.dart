// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Utility functions for threading test configuration through zones.

import 'dart:async';

/// Keys used for zone values by the test framework.
///
/// Enumerated here, so [runInZone] can copy the entire test running context
/// when running.
class TestZoneProperty {
  static const values = [#test.invoker, #test.declarer, #runCount, #test.managedErrorZone];
}

/// A callback and the zone in which it was declared.
class CapturedCallback {
  final Function fn;
  final Zone zone;

  CapturedCallback(this.fn, this.zone);

  @override
  String toString() => 'CapturedCallback($fn in $zone)';
}

/// Runs [function] in a new zone forked from [zone].
///
/// Sets [values] as zone values, but also inherits all unset
/// [TestZoneProperty] keys from [of], defaulting to [Zone.current] if
/// `of` is omitted.
///
/// Sets zone handlers from [specification] if provided.
R runInZone<R>(Zone zone, R Function() function,
    {Map<Object?, Object?>? values,
    ZoneSpecification? specification,
    Zone? of}) {
  of ??= Zone.current;
  values = {
    for (var property in TestZoneProperty.values)
      if (values == null || !values.containsKey(property))
        if (zone[property] == null)
          if (of[property] case final currentValue?) property: currentValue,
    ...?values
  };
  if (values.isEmpty) values = null;
  return zone
      .fork(specification: specification, zoneValues: values)
      .run<R>(function);
}
