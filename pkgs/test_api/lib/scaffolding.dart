// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// {@canonicalFor on_platform.OnPlatform}
/// {@canonicalFor retry.Retry}
/// {@canonicalFor skip.Skip}
/// {@canonicalFor tags.Tags}
/// {@canonicalFor test_on.TestOn}
/// {@canonicalFor timeout.Timeout}
library test_api.scaffolding;

export 'src/backend/configuration/on_platform.dart' show OnPlatform;
export 'src/backend/configuration/retry.dart' show Retry;
export 'src/backend/configuration/skip.dart' show Skip;
export 'src/backend/configuration/tags.dart' show Tags;
export 'src/backend/configuration/test_on.dart' show TestOn;
export 'src/backend/configuration/timeout.dart' show Timeout;
export 'src/scaffolding/spawn_hybrid.dart' show spawnHybridCode, spawnHybridUri;
export 'src/scaffolding/test_structure.dart'
    show addTearDown, group, setUp, setUpAll, tearDown, tearDownAll, test;
export 'src/scaffolding/utils.dart'
    show markTestSkipped, printOnFailure, pumpEventQueue, registerException;
