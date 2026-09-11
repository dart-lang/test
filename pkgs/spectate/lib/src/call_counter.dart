// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A counter that records invocations of a wrapped callback.
final class CallCounter {
  int _callCount = 0;

  CallCounter();

  /// The number of times the callback has been called.
  int get callCount => _callCount;

  /// Whether the callback has been called at least once.
  bool get called => _callCount > 0;

  void _increment() {
    _callCount++;
  }
}

extension CallCounter0 on void Function() {
  (CallCounter, void Function()) get countCalls {
    final counter = CallCounter();
    void wrapped() {
      counter._increment();
      this();
    }

    return (counter, wrapped);
  }
}

extension CallCounterAsync0 on Future<void> Function() {
  (CallCounter, Future<void> Function()) get countCalls {
    final counter = CallCounter();
    Future<void> wrapped() {
      counter._increment();
      return this();
    }

    return (counter, wrapped);
  }
}

extension CallCounter1<T0> on void Function(T0) {
  (CallCounter, void Function(T0)) get countCalls {
    final counter = CallCounter();
    void wrapped(T0 a0) {
      counter._increment();
      this(a0);
    }

    return (counter, wrapped);
  }
}

extension CallCounterAsync1<T0> on Future<void> Function(T0) {
  (CallCounter, Future<void> Function(T0)) get countCalls {
    final counter = CallCounter();
    Future<void> wrapped(T0 a0) {
      counter._increment();
      return this(a0);
    }

    return (counter, wrapped);
  }
}

extension CallCounter2<T0, T1> on void Function(T0, T1) {
  (CallCounter, void Function(T0, T1)) get countCalls {
    final counter = CallCounter();
    void wrapped(T0 a0, T1 a1) {
      counter._increment();
      this(a0, a1);
    }

    return (counter, wrapped);
  }
}

extension CallCounterAsync2<T0, T1> on Future<void> Function(T0, T1) {
  (CallCounter, Future<void> Function(T0, T1)) get countCalls {
    final counter = CallCounter();
    Future<void> wrapped(T0 a0, T1 a1) {
      counter._increment();
      return this(a0, a1);
    }

    return (counter, wrapped);
  }
}

extension CallCounter3<T0, T1, T2> on void Function(T0, T1, T2) {
  (CallCounter, void Function(T0, T1, T2)) get countCalls {
    final counter = CallCounter();
    void wrapped(T0 a0, T1 a1, T2 a2) {
      counter._increment();
      this(a0, a1, a2);
    }

    return (counter, wrapped);
  }
}

extension CallCounterAsync3<T0, T1, T2> on Future<void> Function(T0, T1, T2) {
  (CallCounter, Future<void> Function(T0, T1, T2)) get countCalls {
    final counter = CallCounter();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2) {
      counter._increment();
      return this(a0, a1, a2);
    }

    return (counter, wrapped);
  }
}

extension CallCounter4<T0, T1, T2, T3> on void Function(T0, T1, T2, T3) {
  (CallCounter, void Function(T0, T1, T2, T3)) get countCalls {
    final counter = CallCounter();
    void wrapped(T0 a0, T1 a1, T2 a2, T3 a3) {
      counter._increment();
      this(a0, a1, a2, a3);
    }

    return (counter, wrapped);
  }
}

extension CallCounterAsync4<T0, T1, T2, T3>
    on Future<void> Function(T0, T1, T2, T3) {
  (CallCounter, Future<void> Function(T0, T1, T2, T3)) get countCalls {
    final counter = CallCounter();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2, T3 a3) {
      counter._increment();
      return this(a0, a1, a2, a3);
    }

    return (counter, wrapped);
  }
}

extension CallCounter5<T0, T1, T2, T3, T4>
    on void Function(T0, T1, T2, T3, T4) {
  (CallCounter, void Function(T0, T1, T2, T3, T4)) get countCalls {
    final counter = CallCounter();
    void wrapped(T0 a0, T1 a1, T2 a2, T3 a3, T4 a4) {
      counter._increment();
      this(a0, a1, a2, a3, a4);
    }

    return (counter, wrapped);
  }
}

extension CallCounterAsync5<T0, T1, T2, T3, T4>
    on Future<void> Function(T0, T1, T2, T3, T4) {
  (CallCounter, Future<void> Function(T0, T1, T2, T3, T4)) get countCalls {
    final counter = CallCounter();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2, T3 a3, T4 a4) {
      counter._increment();
      return this(a0, a1, a2, a3, a4);
    }

    return (counter, wrapped);
  }
}
