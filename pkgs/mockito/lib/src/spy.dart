// Copyright 2016 Dart Mockito authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// This file is intentionally separated from 'mock.dart' in order to avoid
// bringing in the mirrors dependency into mockito.dart.
import 'dart:mirrors';

import 'mock.dart' show Mock, setDefaultResponse;

import 'package:mockito/src/call_pair.dart';

/// Sets the default response of [mock] to be delegated to [spyOn].
///
/// __Example use__:
///     var mockAnimal = new MockAnimal();
///     var realAnimal = new RealAnimal();
///     spy(mockAnimal, realAnimal);
E spy<E>(Mock mock, E spyOn) {
  var mirror = reflect(spyOn);
  setDefaultResponse(
    mock,
    () => new CallPair.allInvocations(mirror.delegate),
  );
  return mock as E;
}
