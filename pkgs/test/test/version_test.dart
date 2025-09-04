// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('testVersion is up to date', () {
    final pubspec = Pubspec.parse(
      File('pkgs/test/pubspec.yaml').readAsStringSync(),
      sourceUrl: Uri.file('pkgs/test/pubspec.yaml'),
    );
    expect(pubspec.version.toString(), testVersion);
  });
}
