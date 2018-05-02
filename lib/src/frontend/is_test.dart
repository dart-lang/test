// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The annotation for marking `test()` like functions.
///
/// It might be used by IDEs to show invocations of such functions in a file
/// structure view to help user navigating in large test files.
///
/// The first parameter of the function must be the description of the test.
const isTest = const Object();

/// The annotation for marking `group()` like functions.
///
/// It might be used by IDEs to show invocations of such functions in a file
/// structure view to help user navigating in large test files.
///
/// The first parameter of the function must be the description of the group.
const isTestGroup = const Object();
