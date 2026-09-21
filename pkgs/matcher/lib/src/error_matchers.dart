// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'type_matcher.dart';

/// A matcher for [ArgumentError].
/// {@example /example/error/is_argument_error.dart}
const isArgumentError = TypeMatcher<ArgumentError>();

/// A matcher for [TypeError].
@Deprecated('CastError has been deprecated in favor of TypeError. ')
const isCastError = TypeMatcher<TypeError>();

/// A matcher for [ConcurrentModificationError].
/// {@example /example/error/is_concurrent_modification_error.dart}
const isConcurrentModificationError =
    TypeMatcher<ConcurrentModificationError>();

/// A matcher for [Error].
@Deprecated(
  'CyclicInitializationError is deprecated and will be removed in Dart 3. '
  'Use `isA<Error>()` instead.',
)
const isCyclicInitializationError = TypeMatcher<Error>();

/// A matcher for [Exception].
/// {@example /example/error/is_exception.dart}
const isException = TypeMatcher<Exception>();

/// A matcher for [FormatException].
/// {@example /example/error/is_format_exception.dart}
const isFormatException = TypeMatcher<FormatException>();

/// A matcher for [NoSuchMethodError].
/// {@example /example/error/is_no_such_method_error.dart}
const isNoSuchMethodError = TypeMatcher<NoSuchMethodError>();

/// A matcher for [TypeError].
@Deprecated(
  'NullThrownError is deprecated and will be removed in Dart 3. '
  'Use `isA<TypeError>()` instead.',
)
const isNullThrownError = TypeMatcher<TypeError>();

/// A matcher for [RangeError].
/// {@example /example/error/is_range_error.dart}
const isRangeError = TypeMatcher<RangeError>();

/// A matcher for [StateError].
/// {@example /example/error/is_state_error.dart}
const isStateError = TypeMatcher<StateError>();

/// A matcher for [UnimplementedError].
/// {@example /example/error/is_unimplemented_error.dart}
const isUnimplementedError = TypeMatcher<UnimplementedError>();

/// A matcher for [UnsupportedError].
/// {@example /example/error/is_unsupported_error.dart}
const isUnsupportedError = TypeMatcher<UnsupportedError>();
