// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A spy that records text printed with `print` during callbacks.
final class PrintSpy {
  final List<String> _prints = [];
  final List<List<String>> _calls = [];

  PrintSpy();

  /// All strings printed across all invocations of the spied callback.
  Iterable<String> get prints => _prints;

  /// The prints recorded for each individual invocation of the spied callback.
  Iterable<Iterable<String>> get calls => _calls;

  /// The number of times the spied callback was invoked.
  int get callCount => _calls.length;

  void _recordCall(List<String> callPrints) {
    _calls.add(callPrints);
  }

  void _recordPrint(List<String> callPrints, String line) {
    _prints.add(line);
    callPrints.add(line);
  }

  /// Runs [callback] synchronously in a [Zone] and returns all text printed
  /// using [print].
  static Iterable<String> spectate(void Function() callback) {
    final prints = <String>[];
    runZoned(
      callback,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          prints.add(line);
        },
      ),
    );
    return List.unmodifiable(prints);
  }

  /// Runs [callback] in a [Zone] and emits all text printed using [print] on
  /// the returned [Stream].
  static Stream<String> spectateAsync(FutureOr<void> Function() callback) {
    final controller = StreamController<String>();
    runZonedGuarded(
      () async {
        try {
          await callback();
          await controller.close();
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
            await controller.close();
          }
        }
      },
      (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          controller.close();
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (!controller.isClosed) {
            controller.add(line);
          }
        },
      ),
    );
    return controller.stream;
  }
}

extension PrintSpy0 on void Function() {
  (PrintSpy, void Function()) get spectatePrint {
    final spy = PrintSpy();
    void wrapped() {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      runZoned(
        this,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpyAsync0 on Future<void> Function() {
  (PrintSpy, Future<void> Function()) get spectatePrint {
    final spy = PrintSpy();
    Future<void> wrapped() {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      return runZoned(
        this,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpy1<T0> on void Function(T0) {
  (PrintSpy, void Function(T0)) get spectatePrint {
    final spy = PrintSpy();
    void wrapped(T0 a0) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      runZoned(
        () => this(a0),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpyAsync1<T0> on Future<void> Function(T0) {
  (PrintSpy, Future<void> Function(T0)) get spectatePrint {
    final spy = PrintSpy();
    Future<void> wrapped(T0 a0) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      return runZoned(
        () => this(a0),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpy2<T0, T1> on void Function(T0, T1) {
  (PrintSpy, void Function(T0, T1)) get spectatePrint {
    final spy = PrintSpy();
    void wrapped(T0 a0, T1 a1) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      runZoned(
        () => this(a0, a1),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpyAsync2<T0, T1> on Future<void> Function(T0, T1) {
  (PrintSpy, Future<void> Function(T0, T1)) get spectatePrint {
    final spy = PrintSpy();
    Future<void> wrapped(T0 a0, T1 a1) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      return runZoned(
        () => this(a0, a1),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpy3<T0, T1, T2> on void Function(T0, T1, T2) {
  (PrintSpy, void Function(T0, T1, T2)) get spectatePrint {
    final spy = PrintSpy();
    void wrapped(T0 a0, T1 a1, T2 a2) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      runZoned(
        () => this(a0, a1, a2),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpyAsync3<T0, T1, T2> on Future<void> Function(T0, T1, T2) {
  (PrintSpy, Future<void> Function(T0, T1, T2)) get spectatePrint {
    final spy = PrintSpy();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      return runZoned(
        () => this(a0, a1, a2),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpy4<T0, T1, T2, T3> on void Function(T0, T1, T2, T3) {
  (PrintSpy, void Function(T0, T1, T2, T3)) get spectatePrint {
    final spy = PrintSpy();
    void wrapped(T0 a0, T1 a1, T2 a2, T3 a3) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      runZoned(
        () => this(a0, a1, a2, a3),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpyAsync4<T0, T1, T2, T3>
    on Future<void> Function(T0, T1, T2, T3) {
  (PrintSpy, Future<void> Function(T0, T1, T2, T3)) get spectatePrint {
    final spy = PrintSpy();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2, T3 a3) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      return runZoned(
        () => this(a0, a1, a2, a3),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpy5<T0, T1, T2, T3, T4> on void Function(T0, T1, T2, T3, T4) {
  (PrintSpy, void Function(T0, T1, T2, T3, T4)) get spectatePrint {
    final spy = PrintSpy();
    void wrapped(T0 a0, T1 a1, T2 a2, T3 a3, T4 a4) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      runZoned(
        () => this(a0, a1, a2, a3, a4),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}

extension PrintSpyAsync5<T0, T1, T2, T3, T4>
    on Future<void> Function(T0, T1, T2, T3, T4) {
  (PrintSpy, Future<void> Function(T0, T1, T2, T3, T4)) get spectatePrint {
    final spy = PrintSpy();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2, T3 a3, T4 a4) {
      final callPrints = <String>[];
      spy._recordCall(callPrints);
      return runZoned(
        () => this(a0, a1, a2, a3, a4),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            spy._recordPrint(callPrints, line);
          },
        ),
      );
    }

    return (spy, wrapped);
  }
}
