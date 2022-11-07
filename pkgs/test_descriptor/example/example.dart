// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test('Directory.rename', () async {
    await d.dir('parent', [
      d.file('sibling', 'sibling-contents'),
      d.dir('old-name', [d.file('child', 'child-contents')])
    ]).create();

    await Directory('${d.sandbox}/parent/old-name')
        .rename('${d.sandbox}/parent/new-name');

    await d.dir('parent', [
      d.file('sibling', 'sibling-contents'),
      d.dir('new-name', [d.file('child', 'child-contents')])
    ]).validate();
  });
}
