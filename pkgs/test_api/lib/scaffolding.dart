// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Deprecated('package:test_api is not intended for general use. '
    'Please use package:test.')
library test_api.scaffolding;

export 'src/scaffolding/on_platform.dart' show OnPlatform;
export 'src/scaffolding/retry.dart' show Retry;
export 'src/scaffolding/skip.dart' show Skip;
export 'src/scaffolding/spawn_hybrid.dart' show spawnHybridUri, spawnHybridCode;
export 'src/scaffolding/tags.dart' show Tags;
export 'src/scaffolding/test_on.dart' show TestOn;
export 'src/scaffolding/timeout.dart' show Timeout;
export 'src/scaffolding/utils.dart'
    show pumpEventQueue, printOnFailure, markTestSkipped;
export 'src/scaffolding/test_structure.dart'
    show group, test, setUp, setUpAll, tearDown, tearDownAll, addTearDown;
