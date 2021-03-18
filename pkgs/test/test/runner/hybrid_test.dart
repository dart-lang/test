// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';
import 'dart:isolate';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  late String packageRoot;
  setUpAll(() async {
    packageRoot = p.absolute(p.dirname(p
        .fromUri(await Isolate.resolvePackageUri(Uri.parse('package:test/')))));
  });

  group('spawnHybridUri():', () {
    group('in the VM', () {
      _spawnHybridUriTests();
    });

    group('in the browser', () {
      _spawnHybridUriTests(['-p', 'chrome']);
    }, tags: 'chrome');

    group('in Node.js', () {
      _spawnHybridUriTests(['-p', 'node']);
    }, tags: 'node');
  });

  group('spawnHybridCode()', () {
    test('loads the code in a separate isolate connected via StreamChannel',
        () {
      expect(spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').stream.toList(), completion(equals([1, 2, 3])));
    });

    test('can use dart:io even when run from a browser', () async {
      var path = p.join(d.sandbox, 'test.dart');
      await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid loads dart:io", () {
            expect(spawnHybridCode("""
              import 'dart:io';

              import 'package:stream_channel/stream_channel.dart';

              void hybridMain(StreamChannel channel) {
                channel.sink
                  ..add(File("$path").readAsStringSync())
                  ..close();
              }
            """).stream.first, completion(contains("hybrid emits numbers")));
          });
        }
      ''').create();

      var test = await runTest(['-p', 'chrome', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder(
              ['+0: hybrid loads dart:io', '+1: All tests passed!']));
      await test.shouldExit(0);
    }, tags: ['chrome']);

    test('forwards data from the test to the hybrid isolate', () async {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.stream.listen((num) {
            channel.sink.add(num + 1);
          });
        }
      ''');
      channel.sink..add(1)..add(2)..add(3);
      expect(channel.stream.take(3).toList(), completion(equals([2, 3, 4])));
    });

    test('passes an initial message to the hybrid isolate', () {
      var code = '''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel, Object message) {
          channel.sink..add(message)..close();
        }
      ''';

      expect(spawnHybridCode(code, message: [1, 2, 3]).stream.first,
          completion(equals([1, 2, 3])));
      expect(spawnHybridCode(code, message: {'a': 'b'}).stream.first,
          completion(equals({'a': 'b'})));
    });

    test('allows the hybrid isolate to send errors across the stream channel',
        () {
      var channel = spawnHybridCode('''
        import "package:stack_trace/stack_trace.dart";
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink.addError("oh no!", Trace.current());
        }
      ''');

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals('oh no!'));
        expect(stackTrace.toString(), contains('hybridMain'));
      }));
    });

    test('sends an unhandled synchronous error across the stream channel', () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          throw "oh no!";
        }
      ''');

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals('oh no!'));
        expect(stackTrace.toString(), contains('hybridMain'));
      }));
    });

    test('sends an unhandled asynchronous error across the stream channel', () {
      var channel = spawnHybridCode('''
        import 'dart:async';

        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          scheduleMicrotask(() {
            throw "oh no!";
          });
        }
      ''');

      channel.stream.listen(null, onError: expectAsync2((error, stackTrace) {
        expect(error.toString(), equals('oh no!'));
        expect(stackTrace.toString(), contains('hybridMain'));
      }));
    });

    test('deserializes TestFailures as TestFailures', () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        import "package:test/test.dart";

        void hybridMain(StreamChannel channel) {
          throw TestFailure("oh no!");
        }
      ''');

      expect(channel.stream.first, throwsA(TypeMatcher<TestFailure>()));
    });

    test('gracefully handles an unserializable message in the VM', () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {}
      ''');

      expect(() => channel.sink.add([].iterator), throwsArgumentError);
    });

    test('gracefully handles an unserializable message in the browser',
        () async {
      await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("invalid message to hybrid", () {
            var channel = spawnHybridCode("""
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {}
            """);

            expect(() => channel.sink.add([].iterator), throwsArgumentError);
          });
        }
      ''').create();

      var test = await runTest(['-p', 'chrome', 'test.dart']);
      expect(
          test.stdout,
          containsInOrder(
              ['+0: invalid message to hybrid', '+1: All tests passed!']));
      await test.shouldExit(0);
    }, tags: ['chrome']);

    test('gracefully handles an unserializable message in the hybrid isolate',
        () {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink.add([].iterator);
        }
      ''');

      channel.stream.listen(null, onError: expectAsync1((error) {
        expect(error.toString(), contains("can't be JSON-encoded."));
      }));
    });

    test('forwards prints from the hybrid isolate', () {
      expect(() async {
        var channel = spawnHybridCode('''
          import "package:stream_channel/stream_channel.dart";

          void hybridMain(StreamChannel channel) {
            print("hi!");
            channel.sink.add(null);
          }
        ''');
        await channel.stream.first;
      }, prints('hi!\n'));
    });

    // This takes special handling, since the code is packed into a data: URI
    // that's imported, URIs don't escape $ by default, and $ isn't allowed in
    // imports.
    test('supports a dollar character in the hybrid code', () {
      expect(spawnHybridCode(r'''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          var value = "bar";
          channel.sink.add("foo${value}baz");
        }
      ''').stream.first, completion('foobarbaz'));
    });

    test('kills the isolate when the test closes the channel', () async {
      var channel = spawnHybridCode('''
        import "dart:async";
        import "dart:io";

        import "package:shelf/shelf.dart" as shelf;
        import "package:shelf/shelf_io.dart" as io;
        import "package:stream_channel/stream_channel.dart";

        hybridMain(StreamChannel channel) async {
          var server = await ServerSocket.bind("localhost", 0);
          server.listen(null);
          channel.sink.add(server.port);
        }
      ''');

      // Expect that the socket disconnects at some point (presumably when the
      // isolate closes).
      var port = await channel.stream.first as int;
      var socket = await Socket.connect('localhost', port);
      expect(socket.listen(null).asFuture(), completes);

      await channel.sink.close();
    }, skip: 'Enable when sdk#28081 is fixed.');

    test('kills the isolate when the hybrid isolate closes the channel',
        () async {
      var channel = spawnHybridCode('''
        import "dart:async";
        import "dart:io";

        import "package:stream_channel/stream_channel.dart";

        hybridMain(StreamChannel channel) async {
          var server = await ServerSocket.bind("localhost", 0);
          server.listen(null);
          channel.sink.add(server.port);
          await channel.stream.first;
          channel.sink.close();
        }
      ''');

      // Expect that the socket disconnects at some point (presumably when the
      // isolate closes).
      var port = await channel.stream.first as int;
      var socket = await Socket.connect('localhost', port);
      expect(socket.listen(null).asFuture(), completes);
      channel.sink.add(null);
    }, skip: 'Enable when sdk#28081 is fixed.');

    test('closes the channel when the hybrid isolate exits', () {
      var channel = spawnHybridCode('''
        import "dart:isolate";

        hybridMain(_) {
          Isolate.current.kill();
        }
      ''');

      expect(channel.stream.toList(), completion(isEmpty));
    });

    test('closes the channel when the test finishes by default', () async {
      await d.file('test.dart', '''
        // @dart=2.7
        import "package:stream_channel/stream_channel.dart";
        import "package:test/test.dart";

        import "${p.toUri(packageRoot)}/test/utils.dart";

        void main() {
          StreamChannel channel;
          test("test 1", () {
            channel = spawnHybridCode("""
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {}
            """);
          });

          test("test 2", () async {
            var isDone = false;
            channel.stream.listen(null, onDone: () => isDone = true);
            await pumpEventQueue();
            expect(isDone, isTrue);
          });
        }
      ''').create();

      var test = await runTest(['test.dart']);
      expect(
          test.stdout,
          containsInOrder(
              ['+0: test 1', '+1: test 2', '+2: All tests passed!']));
      await test.shouldExit(0);
    });

    test('persists across multiple tests with stayAlive: true', () async {
      await d.file('test.dart', '''
        import "dart:async";

        import "package:async/async.dart";
        import "package:stream_channel/stream_channel.dart";

        import "package:test/test.dart";

        void main() {
          late StreamQueue queue;
          late StreamSink sink;
          setUpAll(() {
            var channel = spawnHybridCode("""
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {
                channel.stream.listen((message) {
                  channel.sink.add(message);
                });
              }
            """, stayAlive: true);
            queue = StreamQueue(channel.stream);
            sink = channel.sink;
          });

          test("echoes a number", () {
            expect(queue.next, completion(equals(123)));
            sink.add(123);
          });

          test("echoes a string", () {
            expect(queue.next, completion(equals("wow")));
            sink.add("wow");
          });
        }
      ''').create();

      var test = await runTest(['test.dart']);
      expect(
          test.stdout,
          containsInOrder([
            '+0: echoes a number',
            '+1: echoes a string',
            '+2: All tests passed!'
          ]));
      await test.shouldExit(0);
    });

    test('can opt out of null safety', () async {
      expect(spawnHybridCode('''
        // @dart=2.9
        import "package:stream_channel/stream_channel.dart";

        // Would cause an error in null safety mode.
        int x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').stream.toList(), completion(equals([1, 2, 3])));
    });

    test('opts in to null safety by default', () async {
      expect(spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        // Use some null safety syntax
        int? x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').stream.toList(), completion(equals([1, 2, 3])));
    });
  });
}

/// Defines tests for `spawnHybridUri()`.
///
/// If [arguments] is given, it's passed on to the invocation of the test
/// runner.
void _spawnHybridUriTests([Iterable<String> arguments = const []]) {
  test('loads a file in a separate isolate connected via StreamChannel',
      () async {
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("hybrid.dart").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').create();

    var test = await runTest(['test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('resolves URIs relative to the test file', () async {
    await d.dir('test/dir/subdir', [
      d.file('test.dart', '''
          import "package:test/test.dart";

          void main() {
            test("hybrid emits numbers", () {
              expect(spawnHybridUri("hybrid.dart").stream.toList(),
                  completion(equals([1, 2, 3])));
            });
          }
        '''),
      d.file('hybrid.dart', '''
          import "package:stream_channel/stream_channel.dart";

          void hybridMain(StreamChannel channel) {
            channel.sink..add(1)..add(2)..add(3)..close();
          }
        '''),
    ]).create();

    var test = await runTest(['test/dir/subdir/test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('resolves root-relative URIs relative to the package root', () async {
    await d.dir('test/dir/subdir', [
      d.file('test.dart', '''
          import "package:test/test.dart";

          void main() {
            test("hybrid emits numbers", () {
              expect(
                  spawnHybridUri("/test/dir/subdir/hybrid.dart")
                      .stream.toList(),
                  completion(equals([1, 2, 3])));
            });
          }
        '''),
      d.file('hybrid.dart', '''
          import "package:stream_channel/stream_channel.dart";

          void hybridMain(StreamChannel channel) {
            channel.sink..add(1)..add(2)..add(3)..close();
          }
        '''),
    ]).create();

    var test = await runTest(['test/dir/subdir/test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('supports absolute file: URIs', () async {
    var url = p.toUri(p.absolute(p.join(d.sandbox, 'hybrid.dart')));
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("$url").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').create();

    var test = await runTest(['test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('supports Uri objects', () async {
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri(Uri.parse("hybrid.dart")).stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').create();

    var test = await runTest(['test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('rejects non-String, non-Uri objects', () {
    expect(() => spawnHybridUri(123), throwsArgumentError);
  });

  test('passes a message to the hybrid isolate', () async {
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid echoes message", () {
            expect(
                spawnHybridUri(Uri.parse("hybrid.dart"), message: 123)
                    .stream.first,
                completion(equals(123)));

            expect(
                spawnHybridUri(Uri.parse("hybrid.dart"), message: "wow")
                    .stream.first,
                completion(equals("wow")));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel, Object message) {
          channel.sink..add(message)..close();
        }
      ''').create();

    var test = await runTest(['test.dart', ...arguments]);
    expect(
        test.stdout,
        containsInOrder(
            ['+0: hybrid echoes message', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('emits an error from the stream channel if the isolate fails to load',
      () {
    expect(spawnHybridUri('non existent file').stream.first,
        throwsA(TypeMatcher<Exception>()));
  });

  test('can opt out of nnbd via language version comments', () async {
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("hybrid.dart").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        // @dart=2.9
        import "package:stream_channel/stream_channel.dart";

        // Would fail if null safety were enabled.
        int x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').create();

    var test = await runTest(['test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('can opt in to nnbd via language version comments', () async {
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("hybrid.dart").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        // @dart=2.12
        import "package:stream_channel/stream_channel.dart";

        // Use some null safety syntax to confirm we are opted in.
        int? x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').create();

    var test = await runTest(['test.dart', ...arguments]);
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });

  test('the default language version is used for hybrid code', () async {
    await d.file('test.dart', '''
        import "package:test/test.dart";

        void main() {
          test("hybrid emits numbers", () {
            expect(spawnHybridUri("hybrid.dart").stream.toList(),
                completion(equals([1, 2, 3])));
          });
        }
      ''').create();

    await d.file('hybrid.dart', '''
        import "package:stream_channel/stream_channel.dart";

        // Would fail if null safety were enabled.
        int x;

        void hybridMain(StreamChannel channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').create();

    // Adds the sandbox dir as a new package to the existing config,
    // opting it out.
    var originalPackageConfig =
        await loadPackageConfigUri((await Isolate.packageConfig)!);
    var extraPackage = Package('_test', Uri.file('${d.sandbox}/'),
        languageVersion: LanguageVersion(2, 9));
    var newConfig = PackageConfig([
      ...originalPackageConfig.packages,
      extraPackage,
    ], extraData: originalPackageConfig.extraData);
    await d.dir('.dart_tool').create();
    await savePackageConfig(newConfig, Directory(d.sandbox));

    var test = await runTest(['test.dart', ...arguments],
        packageConfig: p.join(d.sandbox, '.dart_tool', 'package_config.json'));
    expect(test.stdout,
        containsInOrder(['+0: hybrid emits numbers', '+1: All tests passed!']));
    await test.shouldExit(0);
  });
}
