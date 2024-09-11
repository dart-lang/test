// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';
import 'package:test/test.dart';

void platformTests() {
  test(
      'Suite relative paths should be resolved by using Uri.base in the browser',
      () async {
    // On the web, suite
    final resolved = Uri.base.resolve('test_data.txt');
    expect(resolved.scheme, startsWith('http'));
    expect(resolved.isAbsolute, true);
    expect(resolved.path, endsWith('test/scaffolding/test_data.txt'));
    expect(
        await get(resolved),
        isA<Response>()
            .having((r) => r.statusCode, 'statusCode', 200)
            .having((r) => r.body, 'body', 'hello\n'));
  });
}
