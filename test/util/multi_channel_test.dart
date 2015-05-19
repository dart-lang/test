// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/src/util/multi_channel.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  var oneToTwo;
  var twoToOne;
  var channel1;
  var channel2;
  setUp(() {
    oneToTwo = new StreamController();
    twoToOne = new StreamController();
    channel1 = new MultiChannel(twoToOne.stream, oneToTwo.sink);
    channel2 = new MultiChannel(oneToTwo.stream, twoToOne.sink);
  });

  group("the default virtual channel", () {
    test("begins connected", () {
      var first = true;
      channel2.stream.listen(expectAsync((message) {
        if (first) {
          expect(message, equals("hello"));
          first = false;
        } else {
          expect(message, equals("world"));
        }
      }, count: 2));

      channel1.sink.add("hello");
      channel1.sink.add("world");
    });

    test("closes the remote virtual channel when it closes", () {
      expect(channel2.stream.toList(), completion(isEmpty));
      expect(channel2.sink.done, completes);

      channel1.sink.close();
    });

    test("closes the local virtual channel when it closes", () {
      expect(channel1.stream.toList(), completion(isEmpty));
      expect(channel1.sink.done, completes);

      channel1.sink.close();
    });

    test("doesn't closes the local virtual channel when the stream "
        "subscription is canceled", () {
      channel1.sink.done.then(expectAsync((_) {}, count: 0));

      channel1.stream.listen((_) {}).cancel();

      // Ensure that there's enough time for the channel to close if it's going
      // to.
      return pumpEventQueue();
    });

    test("closes the underlying channel when it closes without any other "
        "virtual channels", () {
      expect(oneToTwo.done, completes);
      expect(twoToOne.done, completes);

      channel1.sink.close();
    });

    test("doesn't close the underlying channel when it closes with other "
        "virtual channels", () {
      oneToTwo.done.then(expectAsync((_) {}, count: 0));
      twoToOne.done.then(expectAsync((_) {}, count: 0));

      // Establish another virtual connection which should keep the underlying
      // connection open.
      channel2.virtualChannel(channel1.virtualChannel().id);
      channel1.sink.close();

      // Ensure that there's enough time for the underlying channel to complete
      // if it's going to.
      return pumpEventQueue();
    });
  });

  group("a locally-created virtual channel", () {
    var virtual1;
    var virtual2;
    setUp(() {
      virtual1 = channel1.virtualChannel();
      virtual2 = channel2.virtualChannel(virtual1.id);
    });

    test("sends messages only to the other virtual channel", () {
      var first = true;
      virtual2.stream.listen(expectAsync((message) {
        if (first) {
          expect(message, equals("hello"));
          first = false;
        } else {
          expect(message, equals("world"));
        }
      }, count: 2));

      // No other virtual channels should receive the message.
      for (var i = 0; i < 10; i++) {
        var virtual = channel2.virtualChannel(channel1.virtualChannel().id);
        virtual.stream.listen(expectAsync((_) {}, count: 0));
      }
      channel2.stream.listen(expectAsync((_) {}, count: 0));

      virtual1.sink.add("hello");
      virtual1.sink.add("world");
    });

    test("closes the remote virtual channel when it closes", () {
      expect(virtual2.stream.toList(), completion(isEmpty));
      expect(virtual2.sink.done, completes);

      virtual1.sink.close();
    });

    test("closes the local virtual channel when it closes", () {
      expect(virtual1.stream.toList(), completion(isEmpty));
      expect(virtual1.sink.done, completes);

      virtual1.sink.close();
    });

    test("doesn't closes the local virtual channel when the stream "
        "subscription is canceled", () {
      virtual1.sink.done.then(expectAsync((_) {}, count: 0));
      virtual1.stream.listen((_) {}).cancel();

      // Ensure that there's enough time for the channel to close if it's going
      // to.
      return pumpEventQueue();
    });

    test("closes the underlying channel when it closes without any other "
        "virtual channels", () async {
      // First close the default channel so we can test the new channel as the
      // last living virtual channel.
      channel1.sink.close();

      await channel2.stream.toList();
      expect(oneToTwo.done, completes);
      expect(twoToOne.done, completes);

      virtual1.sink.close();
    });

    test("doesn't close the underlying channel when it closes with other "
        "virtual channels", () {
      oneToTwo.done.then(expectAsync((_) {}, count: 0));
      twoToOne.done.then(expectAsync((_) {}, count: 0));

      virtual1.sink.close();

      // Ensure that there's enough time for the underlying channel to complete
      // if it's going to.
      return pumpEventQueue();
    });

    test("doesn't conflict with a remote virtual channel", () {
      var virtual3 = channel2.virtualChannel();
      var virtual4 = channel1.virtualChannel(virtual3.id);

      // This is an implementation detail, but we assert it here to make sure
      // we're properly testing two channels with the same id.
      expect(virtual1.id, equals(virtual3.id));

      virtual2.stream.listen(
          expectAsync((message) => expect(message, equals("hello"))));
      virtual4.stream.listen(
          expectAsync((message) => expect(message, equals("goodbye"))));

      virtual1.sink.add("hello");
      virtual3.sink.add("goodbye");
    });
  });

  group("a remotely-created virtual channel", () {
    var virtual1;
    var virtual2;
    setUp(() {
      virtual1 = channel1.virtualChannel();
      virtual2 = channel2.virtualChannel(virtual1.id);
    });

    test("sends messages only to the other virtual channel", () {
      var first = true;
      virtual1.stream.listen(expectAsync((message) {
        if (first) {
          expect(message, equals("hello"));
          first = false;
        } else {
          expect(message, equals("world"));
        }
      }, count: 2));

      // No other virtual channels should receive the message.
      for (var i = 0; i < 10; i++) {
        var virtual = channel2.virtualChannel(channel1.virtualChannel().id);
        virtual.stream.listen(expectAsync((_) {}, count: 0));
      }
      channel1.stream.listen(expectAsync((_) {}, count: 0));

      virtual2.sink.add("hello");
      virtual2.sink.add("world");
    });

    test("closes the remote virtual channel when it closes", () {
      expect(virtual1.stream.toList(), completion(isEmpty));
      expect(virtual1.sink.done, completes);

      virtual2.sink.close();
    });

    test("closes the local virtual channel when it closes", () {
      expect(virtual2.stream.toList(), completion(isEmpty));
      expect(virtual2.sink.done, completes);

      virtual2.sink.close();
    });

    test("doesn't closes the local virtual channel when the stream "
        "subscription is canceled", () {
      virtual2.sink.done.then(expectAsync((_) {}, count: 0));
      virtual2.stream.listen((_) {}).cancel();

      // Ensure that there's enough time for the channel to close if it's going
      // to.
      return pumpEventQueue();
    });

    test("closes the underlying channel when it closes without any other "
        "virtual channels", () async {
      // First close the default channel so we can test the new channel as the
      // last living virtual channel.
      channel2.sink.close();

      await channel1.stream.toList();
      expect(oneToTwo.done, completes);
      expect(twoToOne.done, completes);

      virtual2.sink.close();
    });

    test("doesn't close the underlying channel when it closes with other "
        "virtual channels", () {
      oneToTwo.done.then(expectAsync((_) {}, count: 0));
      twoToOne.done.then(expectAsync((_) {}, count: 0));

      virtual2.sink.close();

      // Ensure that there's enough time for the underlying channel to complete
      // if it's going to.
      return pumpEventQueue();
    });

    test("doesn't allow another virtual channel with the same id", () {
      expect(() => channel2.virtualChannel(virtual1.id),
          throwsArgumentError);
    });
  });

  group("when the underlying stream", () {
    var virtual1;
    var virtual2;
    setUp(() {
      virtual1 = channel1.virtualChannel();
      virtual2 = channel2.virtualChannel(virtual1.id);
    });

    test("closes, all virtual channels close", () {
      expect(channel1.stream.toList(), completion(isEmpty));
      expect(channel1.sink.done, completes);
      expect(channel2.stream.toList(), completion(isEmpty));
      expect(channel2.sink.done, completes);
      expect(virtual1.stream.toList(), completion(isEmpty));
      expect(virtual1.sink.done, completes);
      expect(virtual2.stream.toList(), completion(isEmpty));
      expect(virtual2.sink.done, completes);

      oneToTwo.close();
    });

    test("closes, no more virtual channels may be created", () {
      expect(channel1.sink.done.then((_) => channel1.virtualChannel()),
          throwsStateError);
      expect(channel2.sink.done.then((_) => channel2.virtualChannel()),
          throwsStateError);

      oneToTwo.close();
    });

    test("emits an error, the error is sent only to the default channel", () {
      channel1.stream.listen(expectAsync((_) {}, count: 0),
          onError: expectAsync((error) => expect(error, equals("oh no"))));
      virtual1.stream.listen(expectAsync((_) {}, count: 0),
          onError: expectAsync((_) {}, count: 0));

      twoToOne.addError("oh no");
    });
  });
}
