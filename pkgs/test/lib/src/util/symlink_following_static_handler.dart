// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_static/shelf_static.dart';

/// Returns a static handler serving files under [root] that follows symlinks
/// within [root] even when they point outside of it.
///
/// Requests whose URL path would escape [root] (for example with `..` or
/// absolute path segments) get a 404 response.
///
/// Tools such as `build_runner test` create precompiled directories made of
/// symlinks to files elsewhere on disk, so the containment check has to be
/// done on the requested path and not on the symlink-resolved path.
shelf.Handler createSymlinkFollowingStaticHandler(String root) {
  final resolvedRoot = Directory(root).resolveSymbolicLinksSync();
  final staticHandler = createStaticHandler(
    resolvedRoot,
    serveFilesOutsidePath: true,
  );
  return (request) {
    // This must match how `shelf_static` builds the file system path.
    final fsPath = p.normalize(
      p.joinAll([resolvedRoot, ...request.url.pathSegments]),
    );
    if (!p.isWithin(resolvedRoot, fsPath)) {
      return shelf.Response.notFound('Not Found');
    }
    return staticHandler(request);
  };
}
