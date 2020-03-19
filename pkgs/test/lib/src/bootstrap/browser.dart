// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_core/src/util/stack_trace_mapper.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/remote_platform_helpers.dart'; // ignore: implementation_imports

import '../runner/browser/post_message_channel.dart';

/// Bootstraps a browser test to communicate with the test runner.
void internalBootstrapBrowserTest(Function Function() getMain) {
  var channel =
      serializeSuite(getMain, hidePrints: false, beforeLoad: () async {
    var serialized =
        await suiteChannel('test.browser.mapper').stream.first as Map?;
    if (serialized == null) return;
    setStackTraceMapper(JSStackTraceMapper.deserialize(serialized)!);
  });
  postMessageChannel().pipe(channel);
}
