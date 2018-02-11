// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils.dart';
import '../util/io.dart';

/// The directory in which the build package generates output.
final generatedDir = p.absolute('.dart_tool/build/generated');

/// Whether this package uses the build package.
final isInUse = new Directory(generatedDir).existsSync();

/// A list of the paths to all DDC modules included in the build output.
///
/// A "module" here refers to a collection of files generated from a single Dart
/// file, such as a `.linked.sum` file or a `.ddc.js` file. The paths don't have
/// any particular extension, and no particular extension is guaranteed to
/// exist.
final List<String> ddcModules = new Directory(generatedDir)
    .listSync(recursive: true)
    .map((entry) {
      if (entry is! File) return null;
      if (entry.path.endsWith(".ddc.js")) {
        return trimSuffix(entry.path, ".ddc.js");
      } else if (entry.path.endsWith(".ddc.js.errors")) {
        return trimSuffix(entry.path, ".ddc.js.errors");
      } else {
        return null;
      }
    })
    .where((path) => path != null)
    .toList();

/// Compiles [url] to JavaScript and returns the contents of the resulting file.
///
/// The [url] must be a `package:` URL.
Future<String> compile(String url) {
  return withTempDir((dir) async {
    var packagesDir = p.join(dir, 'packages');
    new Directory(packagesDir).createSync();

    // Copy the DDC summaries into the target directory so module root stuff
    // will work properly.
    await streamWait(
        new Directory(generatedDir).list(),
        (entry) => new Link(p.join(packagesDir, p.basename(entry.path)))
            .create(p.join(p.absolute(entry.path), 'lib')));

    var jsPathInDir = p.join(dir, 'out.dart.js');
    var arguments = [
      "--module-root=$dir",
      "--library-root=$dir",
      "--summary-extension=linked.sum",
      "--out=$jsPathInDir",
      url
    ];
    arguments.addAll(ddcModules.expand((path) {
      var components = p.split(p.relative(path, from: generatedDir));
      if (components[1] != 'lib') return [];

      var package = components.first;
      var pathInLib = p.joinAll(components.skip(2));
      var summaryPath =
          p.join(dir, "packages", package, "$pathInLib.linked.sum");
      if (!new File(summaryPath).existsSync()) return [];

      return ["--summary", summaryPath];
    }));

    var buffer = new StringBuffer();
    var process =
        await Process.start(p.join(sdkDir, 'bin', 'dartdevc'), arguments);
    await Future.wait([
      UTF8.decoder.bind(process.stdout).listen(buffer.write).asFuture(),
      UTF8.decoder.bind(process.stderr).listen(buffer.write).asFuture()
    ]);

    var exitCode = await process.exitCode;
    var output = buffer.toString();
    if (output.isNotEmpty) print(output);

    if (exitCode == 0) return new File(jsPathInDir).readAsStringSync();

    throw "DDC failed to compile test infrastructure.\n"
        "You may need to re-run `pub run build_runner build`.";
  });
}
