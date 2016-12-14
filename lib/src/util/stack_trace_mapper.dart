// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:package_resolver/package_resolver.dart';
import 'package:source_map_stack_trace/source_map_stack_trace.dart' as mapper;
import 'package:source_maps/source_maps.dart';

/// A class for mapping JS stack traces to Dart stack traces using source maps.
class StackTraceMapper {
  /// The parsed source map.
  final Mapping _mapping;

  /// The package resolution information passed to dart2js.
  final SyncPackageResolver _packageResolver;

  /// The URI of the SDK root from which dart2js loaded its sources.
  final Uri _sdkRoot;

  StackTraceMapper(String contents,
      {Uri mapUrl, SyncPackageResolver packageResolver, Uri sdkRoot})
      : _mapping = parseExtended(contents, mapUrl: mapUrl),
        _packageResolver = packageResolver,
        _sdkRoot = sdkRoot;

  /// Converts [trace] into a Dart stack trace.
  StackTrace mapStackTrace(StackTrace trace) =>
      mapper.mapStackTrace(_mapping, trace,
          packageResolver: _packageResolver, sdkRoot: _sdkRoot);
}
