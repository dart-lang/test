// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.stack_trace_mapper;

import 'package:source_map_stack_trace/source_map_stack_trace.dart' as mapper;
import 'package:source_maps/source_maps.dart';

/// A class for mapping JS stack traces to Dart stack traces using source maps.
class StackTraceMapper {
  /// The parsed source map.
  final Mapping _mapping;

  /// The URI of the package root, as passed to dart2js.
  final Uri _packageRoot;

  /// The URI of the SDK root from which dart2js loaded its sources.
  final Uri _sdkRoot;

  StackTraceMapper(String contents, {Uri mapUrl, Uri packageRoot, Uri sdkRoot})
    : _mapping = parse(contents, mapUrl: mapUrl),
      _packageRoot = packageRoot,
      _sdkRoot = sdkRoot;

  /// Converts [trace] into a Dart stack trace.
  StackTrace mapStackTrace(StackTrace trace) =>
      mapper.mapStackTrace(_mapping, trace,
          packageRoot: _packageRoot, sdkRoot: _sdkRoot);
}
