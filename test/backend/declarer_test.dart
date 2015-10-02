// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/src/backend/declarer.dart';
import 'package:test/src/backend/group.dart';
import 'package:test/src/backend/invoker.dart';
import 'package:test/src/backend/suite.dart';
import 'package:test/src/backend/test.dart';
import 'package:test/src/frontend/timeout.dart';
import 'package:test/test.dart';

import '../utils.dart';

Suite _suite;

void main() {
  setUp(() {
    _suite = new Suite([]);
  });

  group(".test()", () {
    test("declares a test with a description and body", () async {
      var bodyRun = false;
      var tests = declare(() {
        test("description", () {
          bodyRun = true;
        });
      });

      expect(tests, hasLength(1));
      expect(tests.single.name, equals("description"));

      await _runTest(tests[0]);
      expect(bodyRun, isTrue);
    });

    test("declares multiple tests", () {
      var tests = declare(() {
        test("description 1", () {});
        test("description 2", () {});
        test("description 3", () {});
      });

      expect(tests, hasLength(3));
      expect(tests[0].name, equals("description 1"));
      expect(tests[1].name, equals("description 2"));
      expect(tests[2].name, equals("description 3"));
    });
  });

  group(".setUp()", () {
    test("is run before all tests", () async {
      var setUpRun = false;
      var tests = declare(() {
        setUp(() => setUpRun = true);

        test("description 1", expectAsync(() {
          expect(setUpRun, isTrue);
          setUpRun = false;
        }, max: 1));

        test("description 2", expectAsync(() {
          expect(setUpRun, isTrue);
          setUpRun = false;
        }, max: 1));
      });

      await _runTest(tests[0]);
      await _runTest(tests[1]);
    });

    test("can return a Future", () {
      var setUpRun = false;
      var tests = declare(() {
        setUp(() {
          return new Future(() => setUpRun = true);
        });

        test("description", expectAsync(() {
          expect(setUpRun, isTrue);
        }, max: 1));
      });

      return _runTest(tests.single);
    });

    test("runs in call order within a group", () async {
      var firstSetUpRun = false;
      var secondSetUpRun = false;
      var thirdSetUpRun = false;
      var tests = declare(() {
        setUp(expectAsync(() async {
          expect(secondSetUpRun, isFalse);
          expect(thirdSetUpRun, isFalse);
          firstSetUpRun = true;
        }));

        setUp(expectAsync(() async {
          expect(firstSetUpRun, isTrue);
          expect(thirdSetUpRun, isFalse);
          secondSetUpRun = true;
        }));

        setUp(expectAsync(() async {
          expect(firstSetUpRun, isTrue);
          expect(secondSetUpRun, isTrue);
          thirdSetUpRun = true;
        }));

        test("description", expectAsync(() {
          expect(firstSetUpRun, isTrue);
          expect(secondSetUpRun, isTrue);
          expect(thirdSetUpRun, isTrue);
        }));
      });

      await _runTest(tests.single);
    });
  });

  group(".tearDown()", () {
    test("is run after all tests", () async {
      var tearDownRun;
      var tests = declare(() {
        setUp(() => tearDownRun = false);
        tearDown(() => tearDownRun = true);

        test("description 1", expectAsync(() {
          expect(tearDownRun, isFalse);
        }, max: 1));

        test("description 2", expectAsync(() {
          expect(tearDownRun, isFalse);
        }, max: 1));
      });

      await _runTest(tests[0]);
      expect(tearDownRun, isTrue);
      await _runTest(tests[1]);
      expect(tearDownRun, isTrue);
    });

    test("is run after an out-of-band failure", () async {
      var tearDownRun;
      var tests = declare(() {
        setUp(() => tearDownRun = false);
        tearDown(() => tearDownRun = true);

        test("description 1", expectAsync(() {
          Invoker.current.addOutstandingCallback();
          new Future(() => throw new TestFailure("oh no"));
        }, max: 1));
      });

      await _runTest(tests.single, shouldFail: true);
      expect(tearDownRun, isTrue);
    });

    test("can return a Future", () async {
      var tearDownRun = false;
      var tests = declare(() {
        tearDown(() {
          return new Future(() => tearDownRun = true);
        });

        test("description", expectAsync(() {
          expect(tearDownRun, isFalse);
        }, max: 1));
      });

      await _runTest(tests.single);
      expect(tearDownRun, isTrue);
    });

    test("isn't run until there are no outstanding callbacks", () async {
      var outstandingCallbackRemoved = false;
      var outstandingCallbackRemovedBeforeTeardown = false;
      var tests = declare(() {
        tearDown(() {
          outstandingCallbackRemovedBeforeTeardown = outstandingCallbackRemoved;
        });

        test("description", () {
          Invoker.current.addOutstandingCallback();
          pumpEventQueue().then((_) {
            outstandingCallbackRemoved = true;
            Invoker.current.removeOutstandingCallback();
          });
        });
      });

      await _runTest(tests.single);
      expect(outstandingCallbackRemovedBeforeTeardown, isTrue);
    });

    test("doesn't complete until there are no outstanding callbacks", () async {
      var outstandingCallbackRemoved = false;
      var tests = declare(() {
        tearDown(() {
          Invoker.current.addOutstandingCallback();
          pumpEventQueue().then((_) {
            outstandingCallbackRemoved = true;
            Invoker.current.removeOutstandingCallback();
          });
        });

        test("description", () {});
      });

      await _runTest(tests.single);
      expect(outstandingCallbackRemoved, isTrue);
    });

    test("runs in reverse call order within a group", () async {
      var firstTearDownRun = false;
      var secondTearDownRun = false;
      var thirdTearDownRun = false;
      var tests = declare(() {
        tearDown(expectAsync(() async {
          expect(secondTearDownRun, isTrue);
          expect(thirdTearDownRun, isTrue);
          firstTearDownRun = true;
        }));

        tearDown(expectAsync(() async {
          expect(firstTearDownRun, isFalse);
          expect(thirdTearDownRun, isTrue);
          secondTearDownRun = true;
        }));

        tearDown(expectAsync(() async {
          expect(firstTearDownRun, isFalse);
          expect(secondTearDownRun, isFalse);
          thirdTearDownRun = true;
        }));

        test("description", expectAsync(() {
          expect(firstTearDownRun, isFalse);
          expect(secondTearDownRun, isFalse);
          expect(thirdTearDownRun, isFalse);
        }, max: 1));
      });

      await _runTest(tests.single);
    });

    test("runs further tearDowns in a group even if one fails", () async {
      var tests = declare(() {
        tearDown(expectAsync(() {}));

        tearDown(() async {
          throw 'error';
        });

        test("description", expectAsync(() {}));
      });

      await _runTest(tests.single, shouldFail: true);
    });
  });

  group("in a group,", () {
    test("tests inherit the group's description", () {
      var entries = declare(() {
        group("group", () {
          test("description", () {});
        });
      });

      expect(entries, hasLength(1));
      expect(entries.single, new isInstanceOf<Group>());
      expect(entries.single.name, equals("group"));
      expect(entries.single.entries, hasLength(1));
      expect(entries.single.entries.single, new isInstanceOf<Test>());
      expect(entries.single.entries.single.name, "group description");
    });

    test("a test's timeout factor is applied to the group's", () {
      var entries = declare(() {
        group("group", () {
          test("test", () {},
              timeout: new Timeout.factor(3));
        }, timeout: new Timeout.factor(2));
      });

      expect(entries, hasLength(1));
      expect(entries.single, new isInstanceOf<Group>());
      expect(entries.single.metadata.timeout.scaleFactor, equals(2));
      expect(entries.single.entries, hasLength(1));
      expect(entries.single.entries.single, new isInstanceOf<Test>());
      expect(entries.single.entries.single.metadata.timeout.scaleFactor,
          equals(6));
    });

    test("a test's timeout factor is applied to the group's duration", () {
      var entries = declare(() {
        group("group", () {
          test("test", () {},
              timeout: new Timeout.factor(2));
        }, timeout: new Timeout(new Duration(seconds: 10)));
      });

      expect(entries, hasLength(1));
      expect(entries.single, new isInstanceOf<Group>());
      expect(entries.single.metadata.timeout.duration,
          equals(new Duration(seconds: 10)));
      expect(entries.single.entries, hasLength(1));
      expect(entries.single.entries.single, new isInstanceOf<Test>());
      expect(entries.single.entries.single.metadata.timeout.duration,
          equals(new Duration(seconds: 20)));
    });

    test("a test's timeout duration is applied over the group's", () {
      var entries = declare(() {
        group("group", () {
          test("test", () {},
              timeout: new Timeout(new Duration(seconds: 15)));
        }, timeout: new Timeout(new Duration(seconds: 10)));
      });

      expect(entries, hasLength(1));
      expect(entries.single, new isInstanceOf<Group>());
      expect(entries.single.metadata.timeout.duration,
          equals(new Duration(seconds: 10)));
      expect(entries.single.entries, hasLength(1));
      expect(entries.single.entries.single, new isInstanceOf<Test>());
      expect(entries.single.entries.single.metadata.timeout.duration,
          equals(new Duration(seconds: 15)));
    });

    group(".setUp()", () {
      test("is scoped to the group", () async {
        var setUpRun = false;
        var entries = declare(() {
          group("group", () {
            setUp(() => setUpRun = true);

            test("description 1", expectAsync(() {
              expect(setUpRun, isTrue);
              setUpRun = false;
            }, max: 1));
          });

          test("description 2", expectAsync(() {
            expect(setUpRun, isFalse);
            setUpRun = false;
          }, max: 1));
        });

        await _runTest(entries[0].entries.single);
        await _runTest(entries[1]);
      });

      test("runs from the outside in", () {
        var outerSetUpRun = false;
        var middleSetUpRun = false;
        var innerSetUpRun = false;
        var entries = declare(() {
          setUp(expectAsync(() {
            expect(middleSetUpRun, isFalse);
            expect(innerSetUpRun, isFalse);
            outerSetUpRun = true;
          }, max: 1));

          group("middle", () {
            setUp(expectAsync(() {
              expect(outerSetUpRun, isTrue);
              expect(innerSetUpRun, isFalse);
              middleSetUpRun = true;
            }, max: 1));

            group("inner", () {
              setUp(expectAsync(() {
                expect(outerSetUpRun, isTrue);
                expect(middleSetUpRun, isTrue);
                innerSetUpRun = true;
              }, max: 1));

              test("description", expectAsync(() {
                expect(outerSetUpRun, isTrue);
                expect(middleSetUpRun, isTrue);
                expect(innerSetUpRun, isTrue);
              }, max: 1));
            });
          });
        });

        return _runTest(entries.single.entries.single.entries.single);
      });

      test("handles Futures when chained", () {
        var outerSetUpRun = false;
        var innerSetUpRun = false;
        var entries = declare(() {
          setUp(expectAsync(() {
            expect(innerSetUpRun, isFalse);
            return new Future(() => outerSetUpRun = true);
          }, max: 1));

          group("inner", () {
            setUp(expectAsync(() {
              expect(outerSetUpRun, isTrue);
              return new Future(() => innerSetUpRun = true);
            }, max: 1));

            test("description", expectAsync(() {
              expect(outerSetUpRun, isTrue);
              expect(innerSetUpRun, isTrue);
            }, max: 1));
          });
        });

        return _runTest(entries.single.entries.single);
      });
    });

    group(".tearDown()", () {
      test("is scoped to the group", () async {
        var tearDownRun;
        var entries = declare(() {
          setUp(() => tearDownRun = false);

          group("group", () {
            tearDown(() => tearDownRun = true);

            test("description 1", expectAsync(() {
              expect(tearDownRun, isFalse);
            }, max: 1));
          });

          test("description 2", expectAsync(() {
            expect(tearDownRun, isFalse);
          }, max: 1));
        });

        await _runTest(entries[0].entries.single);
        expect(tearDownRun, isTrue);
        await _runTest(entries[1]);
        expect(tearDownRun, isFalse);
      });

      test("runs from the inside out", () async {
        var innerTearDownRun = false;
        var middleTearDownRun = false;
        var outerTearDownRun = false;
        var entries = declare(() {
          tearDown(expectAsync(() {
            expect(innerTearDownRun, isTrue);
            expect(middleTearDownRun, isTrue);
            outerTearDownRun = true;
          }, max: 1));

          group("middle", () {
            tearDown(expectAsync(() {
              expect(innerTearDownRun, isTrue);
              expect(outerTearDownRun, isFalse);
              middleTearDownRun = true;
            }, max: 1));

            group("inner", () {
              tearDown(expectAsync(() {
                expect(outerTearDownRun, isFalse);
                expect(middleTearDownRun, isFalse);
                innerTearDownRun = true;
              }, max: 1));

              test("description", expectAsync(() {
                expect(outerTearDownRun, isFalse);
                expect(middleTearDownRun, isFalse);
                expect(innerTearDownRun, isFalse);
              }, max: 1));
            });
          });
        });

        await _runTest(entries.single.entries.single.entries.single);
        expect(innerTearDownRun, isTrue);
        expect(middleTearDownRun, isTrue);
        expect(outerTearDownRun, isTrue);
      });

      test("handles Futures when chained", () async {
        var outerTearDownRun = false;
        var innerTearDownRun = false;
        var entries = declare(() {
          tearDown(expectAsync(() {
            expect(innerTearDownRun, isTrue);
            return new Future(() => outerTearDownRun = true);
          }, max: 1));

          group("inner", () {
            tearDown(expectAsync(() {
              expect(outerTearDownRun, isFalse);
              return new Future(() => innerTearDownRun = true);
            }, max: 1));

            test("description", expectAsync(() {
              expect(outerTearDownRun, isFalse);
              expect(innerTearDownRun, isFalse);
            }, max: 1));
          });
        });

        await _runTest(entries.single.entries.single);
        expect(innerTearDownRun, isTrue);
        expect(outerTearDownRun, isTrue);
      });

      test("runs outer callbacks even when inner ones fail", () async {
        var outerTearDownRun = false;
        var entries = declare(() {
          tearDown(() {
            return new Future(() => outerTearDownRun = true);
          });

          group("inner", () {
            tearDown(() {
              throw 'inner error';
            });

            test("description", expectAsync(() {
              expect(outerTearDownRun, isFalse);
            }, max: 1));
          });
        });

        await _runTest(entries.single.entries.single, shouldFail: true);
        expect(outerTearDownRun, isTrue);
      });
    });
  });
}

/// Runs [test].
///
/// This automatically sets up an `onError` listener to ensure that the test
/// doesn't throw any invisible exceptions.
Future _runTest(Test test, {bool shouldFail: false}) {
  var liveTest = test.load(_suite);

  liveTest.onError.listen(shouldFail
      ? expectAsync((_) {})
      : (error) => registerException(error.error, error.stackTrace));

  return liveTest.run();
}
