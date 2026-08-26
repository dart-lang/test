// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Exit code constants.
///
/// From [the BSD sysexits manpage][manpage]. Not every constant here is used.
///
/// [manpage]: http://www.freebsd.org/cgi/man.cgi?query=sysexits
/// The command was used incorrectly.
const usage = 64;

/// The input data was incorrect.
const data = 65;

/// An input file did not exist or was unreadable.
const noInput = 66;

/// An internal software error has been detected.
const software = 70;

/// No tests were ran.
const noTestsRan = 79;
