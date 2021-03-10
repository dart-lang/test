// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:matcher/matcher.dart';

import 'throws_matcher.dart';

/// A matcher for functions that throw ArgumentError.
const Matcher throwsArgumentError = Throws(isArgumentError);

/// A matcher for functions that throw ConcurrentModificationError.
const Matcher throwsConcurrentModificationError =
    Throws(isConcurrentModificationError);

/// A matcher for functions that throw CyclicInitializationError.
const Matcher throwsCyclicInitializationError =
    Throws(isCyclicInitializationError);

/// A matcher for functions that throw Exception.
const Matcher throwsException = Throws(isException);

/// A matcher for functions that throw FormatException.
const Matcher throwsFormatException = Throws(isFormatException);

/// A matcher for functions that throw NoSuchMethodError.
const Matcher throwsNoSuchMethodError = Throws(isNoSuchMethodError);

/// A matcher for functions that throw NullThrownError.
const Matcher throwsNullThrownError = Throws(isNullThrownError);

/// A matcher for functions that throw RangeError.
const Matcher throwsRangeError = Throws(isRangeError);

/// A matcher for functions that throw StateError.
const Matcher throwsStateError = Throws(isStateError);

/// A matcher for functions that throw Exception.
const Matcher throwsUnimplementedError = Throws(isUnimplementedError);

/// A matcher for functions that throw UnsupportedError.
const Matcher throwsUnsupportedError = Throws(isUnsupportedError);
