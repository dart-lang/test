// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// ChecksGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:checks/checks.dart';
import 'package:checks/context.dart' as _i1;

extension TypedDataChecks on _i1.Subject<_i2.TypedData> {
  _i1.Subject<int> get elementSizeInBytes =>
      has('elementSizeInBytes', (v) => v.elementSizeInBytes);

  _i1.Subject<int> get offsetInBytes =>
      has('offsetInBytes', (v) => v.offsetInBytes);

  _i1.Subject<int> get lengthInBytes =>
      has('lengthInBytes', (v) => v.lengthInBytes);

  _i1.Subject<_i2.ByteBuffer> get buffer => has('buffer', (v) => v.buffer);
}
