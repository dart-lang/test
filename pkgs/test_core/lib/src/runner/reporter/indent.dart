// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Indent each line in [string] by 2 spaces.
String indent(String text) {
  var lines = text.split('\n');
  if (lines.length == 1) return '  $text';

  var buffer = StringBuffer();

  for (var line in lines.take(lines.length - 1)) {
    buffer.writeln('  $line');
  }
  buffer.write('  ${lines.last}');
  return buffer.toString();
}
