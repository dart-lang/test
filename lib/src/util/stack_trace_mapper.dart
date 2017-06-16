// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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

  /// The contents of the source map.
  final String _contents;

  /// The URI of the source map.
  final Uri _mapUrl;

  StackTraceMapper(this._contents,
      {Uri mapUrl, SyncPackageResolver packageResolver, Uri sdkRoot})
      : _mapping = parseExtended(_contents, mapUrl: mapUrl),
        _mapUrl = mapUrl,
        _packageResolver = packageResolver,
        _sdkRoot = sdkRoot;

  /// Converts [trace] into a Dart stack trace.
  StackTrace mapStackTrace(StackTrace trace) =>
      mapper.mapStackTrace(_mapping, trace,
          packageResolver: _packageResolver, sdkRoot: _sdkRoot);

  /// Returns a Map representation which is suitable for JSON serialization.
  Map<String, dynamic> serialize() {
    return {
      'contents': _contents,
      'sdkRoot': _sdkRoot?.toString(),
      'packageConfigMap':
          _serializablePackageConfigMap(_packageResolver.packageConfigMap),
      'packageRoot': _packageResolver.packageRoot?.toString(),
      'mapUrl': _mapUrl?.toString(),
    };
  }

  /// Returns a Future which will resolve to a [StackTraceMapper] contained in
  /// the provided serialized representation.
  static Future<StackTraceMapper> deserialize(Map serialized) async {
    String packageRoot = serialized['packageRoot'] ?? '';
    return new StackTraceMapper(serialized['contents'],
        sdkRoot: Uri.parse(serialized['sdkRoot']),
        packageResolver: packageRoot.isNotEmpty
            ? await new PackageResolver.root(
                    Uri.parse(serialized['packageRoot']))
                .asSync
            : await new PackageResolver.config(_deserializePackageConfigMap(
                    serialized['packageConfigMap']))
                .asSync,
        mapUrl: Uri.parse(serialized['mapUrl']));
  }

  static Map<String, String> _serializablePackageConfigMap(
      Map<String, Uri> packageConfigMap) {
    var result = {};
    for (var key in packageConfigMap.keys) {
      result[key] = '${packageConfigMap[key]}';
    }
    return result;
  }

  static Map<String, Uri> _deserializePackageConfigMap(
      Map<String, String> serialized) {
    var result = {};
    for (var key in serialized.keys) {
      result[key] = Uri.parse(serialized[key]);
    }
    return result;
  }
}
