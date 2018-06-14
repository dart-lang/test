// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'type_matcher.dart';

/// A matcher for [ArgumentError].
const isArgumentError = const TypeMatcher<ArgumentError>();

/// A matcher for [ConcurrentModificationError].
const isConcurrentModificationError =
    const TypeMatcher<ConcurrentModificationError>();

/// A matcher for [CyclicInitializationError].
const isCyclicInitializationError =
    const TypeMatcher<CyclicInitializationError>();

/// A matcher for [Exception].
const isException = const TypeMatcher<Exception>();

/// A matcher for [FormatException].
const isFormatException = const TypeMatcher<FormatException>();

/// A matcher for [NoSuchMethodError].
const isNoSuchMethodError = const TypeMatcher<NoSuchMethodError>();

/// A matcher for [NullThrownError].
const isNullThrownError = const TypeMatcher<NullThrownError>();

/// A matcher for [RangeError].
const isRangeError = const TypeMatcher<RangeError>();

/// A matcher for [StateError].
const isStateError = const TypeMatcher<StateError>();

/// A matcher for [UnimplementedError].
const isUnimplementedError = const TypeMatcher<UnimplementedError>();

/// A matcher for [UnsupportedError].
const isUnsupportedError = const TypeMatcher<UnsupportedError>();
