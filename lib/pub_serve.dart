// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:barback/barback.dart';
import 'package:path/path.dart' as p;

/// A transformer that injects bootstrapping code used by the test runner to run
/// tests against a "pub serve" instance.
///
/// This doesn't modify existing code at all, it just adds wrapper files that
/// can be used to load isolates or iframes.
class PubServeTransformer extends Transformer implements DeclaringTransformer {
  final allowedExtensions = ".dart";

  PubServeTransformer.asPlugin();

  void declareOutputs(DeclaringTransform transform) {
    var id = transform.primaryId;
    transform.declareOutput(id.addExtension('.vm_test.dart'));
    transform.declareOutput(id.addExtension('.browser_test.dart'));
    transform.declareOutput(id.addExtension('.browser_test.html'));
  }

  void apply(Transform transform) {
    var id = transform.primaryInput.id;

    transform.addOutput(
        new Asset.fromString(id.addExtension('.vm_test.dart'), '''
import "package:test/src/backend/metadata.dart";
import "package:test/src/runner/vm/isolate_listener.dart";

import "${p.url.basename(id.path)}" as test;

void main(_, Map message) {
  var sendPort = message['reply'];
  var metadata = new Metadata.deserialize(message['metadata']);
  IsolateListener.start(sendPort, metadata, () => test.main);
}
'''));

    var browserId = id.addExtension('.browser_test.dart');
    transform.addOutput(new Asset.fromString(browserId, '''
import "package:test/src/runner/browser/iframe_listener.dart";

import "${p.url.basename(id.path)}" as test;

void main(_) {
  IframeListener.start(() => test.main);
}
'''));

    transform.addOutput(
        new Asset.fromString(id.addExtension('.browser_test.html'), '''
<!DOCTYPE html>
<html>
<head>
  <title>${HTML_ESCAPE.convert(id.path)} Test</title>
  <script src="${HTML_ESCAPE.convert(p.url.basename(browserId.path))}.js">
  </script>
</head>
</html>
'''));
  }
}
