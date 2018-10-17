// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:matcher/matcher.dart';

import 'throws_matcher.dart';

/// A matcher for functions that throw ArgumentError.
const Matcher throwsArgumentError =
    // ignore: deprecated_member_use
    Throws(isArgumentError);

/// A matcher for functions that throw ConcurrentModificationError.
const Matcher throwsConcurrentModificationError =
    // ignore: deprecated_member_use
    Throws(isConcurrentModificationError);

/// A matcher for functions that throw CyclicInitializationError.
const Matcher throwsCyclicInitializationError =
    // ignore: deprecated_member_use
    Throws(isCyclicInitializationError);

/// A matcher for functions that throw Exception.
const Matcher throwsException =
    // ignore: deprecated_member_use
    Throws(isException);

/// A matcher for functions that throw FormatException.
const Matcher throwsFormatException =
    // ignore: deprecated_member_use
    Throws(isFormatException);

/// A matcher for functions that throw NoSuchMethodError.
const Matcher throwsNoSuchMethodError =
    // ignore: deprecated_member_use
    Throws(isNoSuchMethodError);

/// A matcher for functions that throw NullThrownError.
const Matcher throwsNullThrownError =
    // ignore: deprecated_member_use
    Throws(isNullThrownError);

/// A matcher for functions that throw RangeError.
const Matcher throwsRangeError =
    // ignore: deprecated_member_use
    Throws(isRangeError);

/// A matcher for functions that throw StateError.
const Matcher throwsStateError =
    // ignore: deprecated_member_use
    Throws(isStateError);

/// A matcher for functions that throw Exception.
const Matcher throwsUnimplementedError =
    // ignore: deprecated_member_use
    Throws(isUnimplementedError);

/// A matcher for functions that throw UnsupportedError.
const Matcher throwsUnsupportedError =
    // ignore: deprecated_member_use
    Throws(isUnsupportedError);
