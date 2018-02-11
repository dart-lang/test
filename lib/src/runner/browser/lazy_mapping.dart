// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS()
library test.src.runner.browser.lazy_mapping;

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart' as source_maps;
import 'package:source_span/source_span.dart';

@JS('\$dartTestGetSourceMap')
external Object _getSourceMap(String module);

/// The URL beneath which test files are served on the browser.
final _rootUrl = p.joinAll(p.split(p.current).take(2));

/// A source mapping that loads source maps as-needed using [_getSourceMap].
class LazyMapping extends source_maps.Mapping {
  final _bundle = new source_maps.MappingBundle();

  source_maps.SourceMapSpan spanFor(int line, int column,
      {Map<String, SourceFile> files, String uri}) {
    if (!_bundle.containsMapping(uri)) {
      var module = uri.endsWith("/dart_sdk.js")
          ? "dart_sdk"
          : p.withoutExtension(p.relative(uri, from: _rootUrl));
      var rawMap = _getSourceMap(module);
      if (rawMap == null) return null;

      var mapping = (rawMap is String
          ? source_maps.parse(rawMap)
          : source_maps.parseJson(rawMap as Map)) as source_maps.SingleMapping;
      mapping.targetUrl = uri;
      if (module != "dart_sdk") {
        mapping.sourceRoot = p.relative(p.dirname(uri), from: _rootUrl) + '/';
      }

      _bundle.addMapping(mapping);
    }

    var span = _bundle.spanFor(line, column, files: files, uri: uri);
    if (span == null || span.start.sourceUrl == null) return null;

    var pathSegments = span.start.sourceUrl.pathSegments;
    if (pathSegments.isNotEmpty && pathSegments.last == 'null') return null;

    return span;
  }
}
