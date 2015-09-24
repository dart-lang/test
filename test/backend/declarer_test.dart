// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/src/backend/declarer.dart';
import 'package:test/src/backend/invoker.dart';
import 'package:test/src/backend/suite.dart';
import 'package:test/src/frontend/timeout.dart';
import 'package:test/test.dart';

import '../utils.dart';

Declarer _declarer;
Suite _suite;

void main() {
  setUp(() {
    _declarer = new Declarer();
    _suite = new Suite([]);
  });

  group(".test()", () {
    test("declares a test with a description and body", () async {
      var bodyRun = false;
      _declarer.test("description", () {
        bodyRun = true;
      });

      expect(_declarer.tests, hasLength(1));
      expect(_declarer.tests.single.name, equals("description"));

      await _runTest(0);
      expect(bodyRun, isTrue);
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
    test("is run before all tests", () async {
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

      await _runTest(0);
      await _runTest(1);
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

    test("runs in call order within a group", () async {
      var firstSetUpRun = false;
      var secondSetUpRun = false;
      var thirdSetUpRun = false;
      _declarer.setUp(expectAsync(() async {
        expect(secondSetUpRun, isFalse);
        expect(thirdSetUpRun, isFalse);
        firstSetUpRun = true;
      }));

      _declarer.setUp(expectAsync(() async {
        expect(firstSetUpRun, isTrue);
        expect(thirdSetUpRun, isFalse);
        secondSetUpRun = true;
      }));

      _declarer.setUp(expectAsync(() async {
        expect(firstSetUpRun, isTrue);
        expect(secondSetUpRun, isTrue);
        thirdSetUpRun = true;
      }));

      _declarer.test("description", expectAsync(() {
        expect(firstSetUpRun, isTrue);
        expect(secondSetUpRun, isTrue);
        expect(thirdSetUpRun, isTrue);
      }));

      await _runTest(0);
    });
  });

  group(".tearDown()", () {
    test("is run after all tests", () async {
      var tearDownRun;
      _declarer.setUp(() => tearDownRun = false);
      _declarer.tearDown(() => tearDownRun = true);

      _declarer.test("description 1", expectAsync(() {
        expect(tearDownRun, isFalse);
      }, max: 1));

      _declarer.test("description 2", expectAsync(() {
        expect(tearDownRun, isFalse);
      }, max: 1));

      await _runTest(0);
      expect(tearDownRun, isTrue);
      await _runTest(1);
      expect(tearDownRun, isTrue);
    });

    test("is run after an out-of-band failure", () async {
      var tearDownRun;
      _declarer.setUp(() => tearDownRun = false);
      _declarer.tearDown(() => tearDownRun = true);

      _declarer.test("description 1", expectAsync(() {
        Invoker.current.addOutstandingCallback();
        new Future(() => throw new TestFailure("oh no"));
      }, max: 1));

      await _runTest(0, shouldFail: true);
      expect(tearDownRun, isTrue);
    });

    test("can return a Future", () async {
      var tearDownRun = false;
      _declarer.tearDown(() {
        return new Future(() => tearDownRun = true);
      });

      _declarer.test("description", expectAsync(() {
        expect(tearDownRun, isFalse);
      }, max: 1));

      await _runTest(0);
      expect(tearDownRun, isTrue);
    });

    test("isn't run until there are no outstanding callbacks", () async {
      var outstandingCallbackRemoved = false;
      var outstandingCallbackRemovedBeforeTeardown = false;
      _declarer.tearDown(() {
        outstandingCallbackRemovedBeforeTeardown = outstandingCallbackRemoved;
      });

      _declarer.test("description", () {
        Invoker.current.addOutstandingCallback();
        pumpEventQueue().then((_) {
          outstandingCallbackRemoved = true;
          Invoker.current.removeOutstandingCallback();
        });
      });

      await _runTest(0);
      expect(outstandingCallbackRemovedBeforeTeardown, isTrue);
    });

    test("doesn't complete until there are no outstanding callbacks", () async {
      var outstandingCallbackRemoved = false;
      _declarer.tearDown(() {
        Invoker.current.addOutstandingCallback();
        pumpEventQueue().then((_) {
          outstandingCallbackRemoved = true;
          Invoker.current.removeOutstandingCallback();
        });
      });

      _declarer.test("description", () {});

      await _runTest(0);
      expect(outstandingCallbackRemoved, isTrue);
    });

    test("runs in reverse call order within a group", () async {
      var firstTearDownRun = false;
      var secondTearDownRun = false;
      var thirdTearDownRun = false;
      _declarer.tearDown(expectAsync(() async {
        expect(secondTearDownRun, isTrue);
        expect(thirdTearDownRun, isTrue);
        firstTearDownRun = true;
      }));

      _declarer.tearDown(expectAsync(() async {
        expect(firstTearDownRun, isFalse);
        expect(thirdTearDownRun, isTrue);
        secondTearDownRun = true;
      }));

      _declarer.tearDown(expectAsync(() async {
        expect(firstTearDownRun, isFalse);
        expect(secondTearDownRun, isFalse);
        thirdTearDownRun = true;
      }));

      _declarer.test("description", expectAsync(() {
        expect(firstTearDownRun, isFalse);
        expect(secondTearDownRun, isFalse);
        expect(thirdTearDownRun, isFalse);
      }, max: 1));

      await _runTest(0);
    });

    test("runs further tearDowns in a group even if one fails", () async {
      _declarer.tearDown(expectAsync(() {}));

      _declarer.tearDown(() async {
        throw 'error';
      });

      _declarer.test("description", expectAsync(() {}));

      await _runTest(0, shouldFail: true);
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

    test("a test's timeout factor is applied to the group's", () {
      _declarer.group("group", () {
        _declarer.test("test", () {},
            timeout: new Timeout.factor(3));
      }, timeout: new Timeout.factor(2));

      expect(_declarer.tests, hasLength(1));
      expect(_declarer.tests.single.metadata.timeout.scaleFactor, equals(6));
    });

    test("a test's timeout factor is applied to the group's duration", () {
      _declarer.group("group", () {
        _declarer.test("test", () {},
            timeout: new Timeout.factor(2));
      }, timeout: new Timeout(new Duration(seconds: 10)));

      expect(_declarer.tests, hasLength(1));
      expect(_declarer.tests.single.metadata.timeout.duration,
          equals(new Duration(seconds: 20)));
    });

    test("a test's timeout duration is applied over the group's", () {
      _declarer.group("group", () {
        _declarer.test("test", () {},
            timeout: new Timeout(new Duration(seconds: 15)));
      }, timeout: new Timeout(new Duration(seconds: 10)));

      expect(_declarer.tests, hasLength(1));
      expect(_declarer.tests.single.metadata.timeout.duration,
          equals(new Duration(seconds: 15)));
    });

    group(".setUp()", () {
      test("is scoped to the group", () async {
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

        await _runTest(0);
        await _runTest(1);
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
    });

    group(".tearDown()", () {
      test("is scoped to the group", () async {
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

        await _runTest(0);
        expect(tearDownRun, isTrue);
        await _runTest(1);
        expect(tearDownRun, isFalse);
      });

      test("runs from the inside out", () async {
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

        await _runTest(0);
        expect(innerTearDownRun, isTrue);
        expect(middleTearDownRun, isTrue);
        expect(outerTearDownRun, isTrue);
      });

      test("handles Futures when chained", () async {
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

        await _runTest(0);
        expect(innerTearDownRun, isTrue);
        expect(outerTearDownRun, isTrue);
      });

      test("runs outer callbacks even when inner ones fail", () async {
        var outerTearDownRun = false;
        _declarer.tearDown(() {
          return new Future(() => outerTearDownRun = true);
        });

        _declarer.group("inner", () {
          _declarer.tearDown(() {
            throw 'inner error';
          });

          _declarer.test("description", expectAsync(() {
            expect(outerTearDownRun, isFalse);
          }, max: 1));
        });

        await _runTest(0, shouldFail: true);
        expect(outerTearDownRun, isTrue);
      });
    });
  });
}

/// Runs the test at [index] defined on [_declarer].
///
/// This automatically sets up an `onError` listener to ensure that the test
/// doesn't throw any invisible exceptions.
Future _runTest(int index, {bool shouldFail: false}) {
  var liveTest = _declarer.tests[index].load(_suite);

  liveTest.onError.listen(shouldFail
      ? expectAsync((_) {})
      : (error) => registerException(error.error, error.stackTrace));

  return liveTest.run();
}
