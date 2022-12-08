// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('spawnHybridUri():', () {
    test('loads a file in a separate isolate connected via StreamChannel',
        () async {
      expect(spawnHybridUri('util/emits_numbers.dart').stream.toList(),
          completion(equals([1, 2, 3])));
    });

    test('resolves root-relative URIs relative to the package root', () async {
      expect(spawnHybridUri('/test/util/emits_numbers.dart').stream.toList(),
          completion(equals([1, 2, 3])));
    });

    test('supports Uri objects', () async {
      expect(
          spawnHybridUri(Uri.parse('util/emits_numbers.dart')).stream.toList(),
          completion(equals([1, 2, 3])));
    });

    test('supports package: uris referencing the root package', () async {
      expect(
          spawnHybridUri(Uri.parse('package:spawn_hybrid/emits_numbers.dart'))
              .stream
              .toList(),
          completion(equals([1, 2, 3])));
    });

    test('supports package: uris referencing dependency packages', () async {
      expect(
          spawnHybridUri(Uri.parse('package:other_package/emits_numbers.dart'))
              .stream
              .toList(),
          completion(equals([1, 2, 3])));
    });

    test('rejects non-String, non-Uri objects', () {
      expect(() => spawnHybridUri(123), throwsArgumentError);
    });

    test('passes a message to the hybrid isolate', () async {
      expect(
          spawnHybridUri('util/echos_message.dart', message: 123).stream.first,
          completion(equals(123)));
      expect(
          spawnHybridUri('util/echos_message.dart', message: 'wow')
              .stream
              .first,
          completion(equals('wow')));
    });

    test('emits an error from the stream channel if the isolate fails to load',
        () {
      expect(spawnHybridUri('non existent file').stream.first,
          throwsA(TypeMatcher<Exception>()));
    });
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

    test('allows a first parameter with type StreamChannel<Object?>', () {
      expect(spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel<Object?> channel) {
          channel.sink..add(1)..add(2)..add(null)..close();
        }
      ''').stream.toList(), completion(equals([1, 2, null])));
    });

    test('gives a good error when the StreamChannel type is not supported', () {
      expect(
          spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel<Object> channel) {
          channel.sink..add(1)..add(2)..add(3)..close();
        }
      ''').stream,
          emitsError(isA<Exception>().having(
              (e) => e.toString(),
              'toString',
              contains(
                  'The first parameter to the top-level hybridMain() must be a '
                  'StreamChannel<dynamic> or StreamChannel<Object?>. More specific '
                  'types such as StreamChannel<Object> are not supported.'))));
    });

    test('can use dart:io even when run from a browser', () async {
      var path = p.join('test', 'hybrid_test.dart');
      expect(spawnHybridCode("""
              import 'dart:io';

              import 'package:stream_channel/stream_channel.dart';

              void hybridMain(StreamChannel channel) {
                channel.sink
                  ..add(File(r"$path").readAsStringSync())
                  ..close();
              }
            """).stream.first, completion(contains('hybrid emits numbers')));
    }, testOn: 'browser');

    test('forwards data from the test to the hybrid isolate', () async {
      var channel = spawnHybridCode('''
        import "package:stream_channel/stream_channel.dart";

        void hybridMain(StreamChannel channel) {
          channel.stream.listen((num) {
            channel.sink.add(num + 1);
          });
        }
      ''');
      channel.sink
        ..add(1)
        ..add(2)
        ..add(3);
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
      var channel = spawnHybridCode('''
        import 'package:stream_channel/stream_channel.dart';

        void hybridMain(StreamChannel channel) {}
      ''');

      expect(() => channel.sink.add([].iterator), throwsArgumentError);
    }, testOn: 'browser');

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

    test('closes the channel when the hybrid isolate exits', () {
      var channel = spawnHybridCode('''
        import "dart:isolate";

        hybridMain(_) {
          Isolate.current.kill();
        }
      ''');

      expect(channel.stream.toList(), completion(isEmpty));
    });

    group('closes the channel when the test finishes by default', () {
      late StreamChannel channel;

      test('test 1', () {
        channel = spawnHybridCode('''
              import 'package:stream_channel/stream_channel.dart';

              void hybridMain(StreamChannel channel) {}
            ''');
      });

      test('test 2', () async {
        var isDone = false;
        channel.stream.listen(null, onDone: () => isDone = true);
        await pumpEventQueue();
        expect(isDone, isTrue);
      });
    });

    group('persists across multiple tests with stayAlive: true', () {
      late StreamQueue queue;
      late StreamSink sink;
      setUpAll(() {
        var channel = spawnHybridCode('''
              import "package:stream_channel/stream_channel.dart";

              void hybridMain(StreamChannel channel) {
                channel.stream.listen((message) {
                  channel.sink.add(message);
                });
              }
            ''', stayAlive: true);
        queue = StreamQueue(channel.stream);
        sink = channel.sink;
      });

      test('echoes a number', () {
        expect(queue.next, completion(equals(123)));
        sink.add(123);
      });

      test('echoes a string', () {
        expect(queue.next, completion(equals('wow')));
        sink.add('wow');
      });
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
