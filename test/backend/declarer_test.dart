// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:unittest/src/backend/declarer.dart';
import 'package:unittest/src/backend/suite.dart';
import 'package:unittest/unittest.dart';

Declarer _declarer;
Suite _suite;

void main() {
  setUp(() {
    _declarer = new Declarer();
    _suite = new Suite("suite", []);
  });

  group(".test()", () {
    test("declares a test with a description and body", () {
      var bodyRun = false;
      _declarer.test("description", () {
        bodyRun = true;
      });

      expect(_declarer.tests, hasLength(1));
      expect(_declarer.tests.single.name, equals("description"));

      return _runTest(0).then(expectAsync((_) {
        expect(bodyRun, isTrue);
      }, max: 1));
    });

    test("declares multiple tests", () {
      _declarer.test("description 1", () {});
      _declarer.test("description 2", () {});
      _declarer.test("description 3", () {});

      expect(_declarer.tests, hasLength(3));
      expect(_declarer.tests[0].name, equals("description 1"));
      expect(_declarer.tests[1].name, equals("description 2"));
      expect(_declarer.tests[2].name, equals("description 3"));
    });
  });

  group(".setUp()", () {
    test("is run before all tests", () {
      var setUpRun = false;
      _declarer.setUp(() => setUpRun = true);

      _declarer.test("description 1", expectAsync(() {
        expect(setUpRun, isTrue);
        setUpRun = false;
      }, max: 1));

      _declarer.test("description 2", expectAsync(() {
        expect(setUpRun, isTrue);
        setUpRun = false;
      }, max: 1));

      return _runTest(0).then((_) => _runTest(1));
    });

    test("can return a Future", () {
      var setUpRun = false;
      _declarer.setUp(() {
        return new Future(() => setUpRun = true);
      });

      _declarer.test("description", expectAsync(() {
        expect(setUpRun, isTrue);
      }, max: 1));

      return _runTest(0);
    });

    test("can't be called multiple times", () {
      _declarer.setUp(() {});
      expect(() => _declarer.setUp(() {}), throwsStateError);
    });
  });

  group(".tearDown()", () {
    test("is run after all tests", () {
      var tearDownRun;
      _declarer.setUp(() => tearDownRun = false);
      _declarer.tearDown(() => tearDownRun = true);

      _declarer.test("description 1", expectAsync(() {
        expect(tearDownRun, isFalse);
      }, max: 1));

      _declarer.test("description 2", expectAsync(() {
        expect(tearDownRun, isFalse);
      }, max: 1));

      return _runTest(0).then((_) {
        expect(tearDownRun, isTrue);
        return _runTest(1);
      }).then((_) => expect(tearDownRun, isTrue));
    });

    test("can return a Future", () {
      var tearDownRun = false;
      _declarer.tearDown(() {
        return new Future(() => tearDownRun = true);
      });

      _declarer.test("description", expectAsync(() {
        expect(tearDownRun, isFalse);
      }, max: 1));

      return _runTest(0).then((_) => expect(tearDownRun, isTrue));
    });

    test("can't be called multiple times", () {
      _declarer.tearDown(() {});
      expect(() => _declarer.tearDown(() {}), throwsStateError);
    });
  });

  group("in a group,", () {
    test("tests inherit the group's description", () {
      _declarer.group("group", () {
        _declarer.test("description", () {});
      });

      expect(_declarer.tests, hasLength(1));
      expect(_declarer.tests.single.name, "group description");
    });

    group(".setUp()", () {
      test("is scoped to the group", () {
        var setUpRun = false;
        _declarer.group("group", () {
          _declarer.setUp(() => setUpRun = true);

          _declarer.test("description 1", expectAsync(() {
            expect(setUpRun, isTrue);
            setUpRun = false;
          }, max: 1));
        });

        _declarer.test("description 2", expectAsync(() {
          expect(setUpRun, isFalse);
          setUpRun = false;
        }, max: 1));

        return _runTest(0).then((_) => _runTest(1));
      });

      test("runs from the outside in", () {
        var outerSetUpRun = false;
        var middleSetUpRun = false;
        var innerSetUpRun = false;
        _declarer.setUp(expectAsync(() {
          expect(middleSetUpRun, isFalse);
          expect(innerSetUpRun, isFalse);
          outerSetUpRun = true;
        }, max: 1));

        _declarer.group("middle", () {
          _declarer.setUp(expectAsync(() {
            expect(outerSetUpRun, isTrue);
            expect(innerSetUpRun, isFalse);
            middleSetUpRun = true;
          }, max: 1));

          _declarer.group("inner", () {
            _declarer.setUp(expectAsync(() {
              expect(outerSetUpRun, isTrue);
              expect(middleSetUpRun, isTrue);
              innerSetUpRun = true;
            }, max: 1));

            _declarer.test("description", expectAsync(() {
              expect(outerSetUpRun, isTrue);
              expect(middleSetUpRun, isTrue);
              expect(innerSetUpRun, isTrue);
            }, max: 1));
          });
        });

        return _runTest(0);
      });

      test("handles Futures when chained", () {
        var outerSetUpRun = false;
        var innerSetUpRun = false;
        _declarer.setUp(expectAsync(() {
          expect(innerSetUpRun, isFalse);
          return new Future(() => outerSetUpRun = true);
        }, max: 1));

        _declarer.group("inner", () {
          _declarer.setUp(expectAsync(() {
            expect(outerSetUpRun, isTrue);
            return new Future(() => innerSetUpRun = true);
          }, max: 1));

          _declarer.test("description", expectAsync(() {
            expect(outerSetUpRun, isTrue);
            expect(innerSetUpRun, isTrue);
          }, max: 1));
        });

        return _runTest(0);
      });

      test("can't be called multiple times", () {
        _declarer.group("group", () {
          _declarer.setUp(() {});
          expect(() => _declarer.setUp(() {}), throwsStateError);
        });
      });
    });

    group(".tearDown()", () {
      test("is scoped to the group", () {
        var tearDownRun;
        _declarer.setUp(() => tearDownRun = false);

        _declarer.group("group", () {
          _declarer.tearDown(() => tearDownRun = true);

          _declarer.test("description 1", expectAsync(() {
            expect(tearDownRun, isFalse);
          }, max: 1));
        });

        _declarer.test("description 2", expectAsync(() {
          expect(tearDownRun, isFalse);
        }, max: 1));

        return _runTest(0).then((_) {
          expect(tearDownRun, isTrue);
          return _runTest(1);
        }).then((_) => expect(tearDownRun, isFalse));
      });

      test("runs from the inside out", () {
        var innerTearDownRun = false;
        var middleTearDownRun = false;
        var outerTearDownRun = false;
        _declarer.tearDown(expectAsync(() {
          expect(innerTearDownRun, isTrue);
          expect(middleTearDownRun, isTrue);
          outerTearDownRun = true;
        }, max: 1));

        _declarer.group("middle", () {
          _declarer.tearDown(expectAsync(() {
            expect(innerTearDownRun, isTrue);
            expect(outerTearDownRun, isFalse);
            middleTearDownRun = true;
          }, max: 1));

          _declarer.group("inner", () {
            _declarer.tearDown(expectAsync(() {
              expect(outerTearDownRun, isFalse);
              expect(middleTearDownRun, isFalse);
              innerTearDownRun = true;
            }, max: 1));

            _declarer.test("description", expectAsync(() {
              expect(outerTearDownRun, isFalse);
              expect(middleTearDownRun, isFalse);
              expect(innerTearDownRun, isFalse);
            }, max: 1));
          });
        });

        return _runTest(0).then((_) {
          expect(innerTearDownRun, isTrue);
          expect(middleTearDownRun, isTrue);
          expect(outerTearDownRun, isTrue);
        });
      });

      test("handles Futures when chained", () {
        var outerTearDownRun = false;
        var innerTearDownRun = false;
        _declarer.tearDown(expectAsync(() {
          expect(innerTearDownRun, isTrue);
          return new Future(() => outerTearDownRun = true);
        }, max: 1));

        _declarer.group("inner", () {
          _declarer.tearDown(expectAsync(() {
            expect(outerTearDownRun, isFalse);
            return new Future(() => innerTearDownRun = true);
          }, max: 1));

          _declarer.test("description", expectAsync(() {
            expect(outerTearDownRun, isFalse);
            expect(innerTearDownRun, isFalse);
          }, max: 1));
        });

        return _runTest(0).then((_) {
          expect(innerTearDownRun, isTrue);
          expect(outerTearDownRun, isTrue);
        });
      });

      test("can't be called multiple times", () {
        _declarer.group("group", () {
          _declarer.tearDown(() {});
          expect(() => _declarer.tearDown(() {}), throwsStateError);
        });
      });
    });
  });
}

/// Runs the test at [index] defined on [_declarer].
///
/// This automatically sets up an `onError` listener to ensure that the test
/// doesn't throw any invisible exceptions.
Future _runTest(int index) {
  var liveTest = _declarer.tests[index].load(_suite);
  liveTest.onError.listen(expectAsync((_) {},
      count: 0, reason: "No errors expected for test #$index."));
  return liveTest.run();
}
