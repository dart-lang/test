// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

String literal(Object? o) {
  if (o == null || o is num || o is bool) return '<$o>';
  // TODO Truncate long strings?
  // TODO: handle strings with embedded `'`
  // TODO: special handling of multi-line strings?
  if (o is String) return "'$o'";
  // TODO Truncate long collections?
  return '$o';
}

Iterable<String> indent(Iterable<String> lines) => lines.map((l) => '  $l');
