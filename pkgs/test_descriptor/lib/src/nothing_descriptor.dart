// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'descriptor.dart';
import 'sandbox.dart';
import 'utils.dart';

/// A descriptor that validates that no file exists with the given name.
///
/// Calling [create] does nothing.
class NothingDescriptor extends Descriptor {
  NothingDescriptor(super.name);

  @override
  Future<void> create([String? parent]) async {}

  @override
  Future<void> validate([String? parent]) async {
    final fullPath = p.join(parent ?? sandbox, name);
    final pretty = prettyPath(fullPath);
    if (File(fullPath).existsSync()) {
      fail('Expected nothing to exist at "$pretty", but found a file.');
    } else if (Directory(fullPath).existsSync()) {
      fail('Expected nothing to exist at "$pretty", but found a directory.');
    } else if (Link(fullPath).existsSync()) {
      fail('Expected nothing to exist at "$pretty", but found a link.');
    }
  }

  @override
  String describe() => 'nothing at "$name"';
}
