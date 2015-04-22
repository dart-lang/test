// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import '../../utils.dart';

void main() {
  group('[throwsArgumentError]', () {
    test("passes when a ArgumentError is thrown", () {
      expect(() => throw new ArgumentError(''), throwsArgumentError);
    });

    test("fails when a non-ArgumentError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsArgumentError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws ArgumentError"));
      });
    });
  });

  group('[throwsConcurrentModificationError]', () {
    test("passes when a ConcurrentModificationError is thrown", () {
      expect(() => throw new ConcurrentModificationError(''),
          throwsConcurrentModificationError);
    });

    test("fails when a non-ConcurrentModificationError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsConcurrentModificationError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws ConcurrentModificationError"));
      });
    });
  });

  group('[throwsCyclicInitializationError]', () {
    test("passes when a CyclicInitializationError is thrown", () {
      expect(() => throw new CyclicInitializationError(''),
          throwsCyclicInitializationError);
    });

    test("fails when a non-CyclicInitializationError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsCyclicInitializationError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws CyclicInitializationError"));
      });
    });
  });

  group('[throwsException]', () {
    test("passes when a Exception is thrown", () {
      expect(() => throw new Exception(''), throwsException);
    });

    test("fails when a non-Exception is thrown", () {
      return runTestBody(() {
        expect(() => throw 'oh no', throwsException);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws Exception"));
      });
    });
  });

  group('[throwsFormatException]', () {
    test("passes when a FormatException is thrown", () {
      expect(() => throw new FormatException(''), throwsFormatException);
    });

    test("fails when a non-FormatException is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsFormatException);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws FormatException"));
      });
    });
  });

  group('[throwsNoSuchMethodError]', () {
    test("passes when a NoSuchMethodError is thrown", () {
      expect(() {
        throw new NoSuchMethodError(null, #name, null, null);
      }, throwsNoSuchMethodError);
    });

    test("fails when a non-NoSuchMethodError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsNoSuchMethodError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws NoSuchMethodError"));
      });
    });
  });

  group('[throwsNullThrownError]', () {
    test("passes when a NullThrownError is thrown", () {
      expect(() => throw null, throwsNullThrownError);
    });

    test("fails when a non-NullThrownError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsNullThrownError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws NullThrownError"));
      });
    });
  });

  group('[throwsRangeError]', () {
    test("passes when a RangeError is thrown", () {
      expect(() => throw new RangeError(''), throwsRangeError);
    });

    test("fails when a non-RangeError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsRangeError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws RangeError"));
      });
    });
  });

  group('[throwsStateError]', () {
    test("passes when a StateError is thrown", () {
      expect(() => throw new StateError(''), throwsStateError);
    });

    test("fails when a non-StateError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsStateError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws StateError"));
      });
    });
  });

  group('[throwsUnimplementedError]', () {
    test("passes when a UnimplementedError is thrown", () {
      expect(() => throw new UnimplementedError(''), throwsUnimplementedError);
    });

    test("fails when a non-UnimplementedError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsUnimplementedError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws UnimplementedError"));
      });
    });
  });

  group('[throwsUnsupportedError]', () {
    test("passes when a UnsupportedError is thrown", () {
      expect(() => throw new UnsupportedError(''), throwsUnsupportedError);
    });

    test("fails when a non-UnsupportedError is thrown", () {
      return runTestBody(() {
        expect(() => throw new Exception(), throwsUnsupportedError);
      }).then((liveTest) {
        expectTestFailed(liveTest,
            startsWith("Expected: throws UnsupportedError"));
      });
    });
  });
}
