// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/src/util/buffered_string_sink.dart';
import 'package:test/test.dart';

void main() {
  BufferedStringSink sink;
  StringBuffer output;

  setUp(() {
    output = new StringBuffer();
    sink = new BufferedStringSink(output.writeln);
  });

  tearDown(() {
    output = null;
    sink = null;
  });

  test('write prints on newline', () {
    sink.write('Hello\n');
    expect(output.toString(), 'Hello\n');
    sink.write('World\n!!!');
    expect(output.toString(), 'Hello\nWorld\n');
  });

  test('write prints previous output on newline', () {
    sink.write('Hello ');
    expect(output.toString(), '');
    sink.write('World\n!!!');
    expect(output.toString(), 'Hello World\n');
  });

  test('writeAll prints on newline', () {
    sink.writeAll(['a', 'b', 'c'], '\n');
    expect(output.toString(), 'a\nb\n');
    sink.writeln();
    expect(output.toString(), 'a\nb\nc\n');
  });

  test('writeAll defaults to empty separator', () {
    sink.writeAll(['a', 'b', 'c']);
    sink.writeln();
    expect(output.toString(), 'abc\n');
  });

  test('writeln appends newline', () {
    sink.writeln('Hello');
    expect(output.toString(), 'Hello\n');
    sink.writeln('World');
    expect(output.toString(), 'Hello\nWorld\n');
  });

  test('writeln prints previous output', () {
    sink.write('Hello ');
    sink.writeln('World');
    expect(output.toString(), 'Hello World\n');
  });
}
