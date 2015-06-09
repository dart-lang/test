// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.print_string_sink;

/// A print function that outputs str followed by a new-line
/// 'dart:core' [print] is the typical example.
typedef void PrintFn(String str);

/// Implementation of StringSink that buffers characters until
/// a newline is seen.
class BufferedStringSink implements StringSink {
  final PrintFn _print;
  var _remaining = '';

  /// if [_print] is not provided, defaults to 'dart:core' [print]
  /// function.
  BufferedStringSink([this._print = print]);

  @override
  void write(Object obj) {
    var str = '$_remaining$obj';
    var splitIndex = str.lastIndexOf('\n');
    if (splitIndex == -1) {
      _remaining = str;
      return;
    }
    if (splitIndex < str.length - 1) {
      _remaining = str.substring(splitIndex + 1);
    } else {
      _remaining = '';
    }
    _print(str.substring(0, splitIndex));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) => write(new String.fromCharCode(charCode));

  @override
  void writeln([Object obj = '']) {
    _print('$_remaining$obj');
    _remaining = '';
  }
}
