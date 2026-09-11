// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

/// An exception thrown when [exit] is called while being spied on by [ExitSpy].
final class ExitException implements Exception {
  /// The exit code passed to [exit].
  final int exitCode;

  ExitException(this.exitCode);

  @override
  String toString() => 'ExitException: $exitCode';
}

/// A spy that records calls to [exit] during callbacks.
final class ExitSpy {
  final List<int> _exitCodes = [];

  ExitSpy();

  /// All exit codes passed to [exit] across all invocations of the spied callback.
  Iterable<int> get exitCodes => _exitCodes;

  /// The first exit code passed to [exit], or `null` if [exit] was not called.
  int? get exitCode => _exitCodes.firstOrNull;

  /// Whether [exit] was called at least once.
  bool get exited => _exitCodes.isNotEmpty;

  /// The number of times [exit] was called.
  int get callCount => _exitCodes.length;

  void _recordExit(int code) {
    _exitCodes.add(code);
  }

  /// Runs [callback] synchronously and returns the exit code if [exit] was called,
  /// or `null` if [callback] finished without calling [exit].
  static int? spectate(void Function() callback) {
    int? code;
    try {
      IOOverrides.runZoned(
        callback,
        exit: (exitCode) {
          code = exitCode;
          throw ExitException(exitCode);
        },
      );
    } on ExitException {
      // Normal interception of exit().
    }
    return code;
  }

  /// Runs [callback] asynchronously and returns the exit code if [exit] was called,
  /// or `null` if [callback] finished without calling [exit].
  static Future<int?> spectateAsync(FutureOr<void> Function() callback) async {
    int? code;
    try {
      await IOOverrides.runZoned(
        () async {
          await callback();
        },
        exit: (exitCode) {
          code = exitCode;
          throw ExitException(exitCode);
        },
      );
    } on ExitException {
      // Normal interception of exit().
    }
    return code;
  }
}

extension ExitSpy0 on void Function() {
  (ExitSpy, void Function()) get spectateExit {
    final spy = ExitSpy();
    void wrapped() {
      try {
        IOOverrides.runZoned(
          this,
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpyAsync0 on Future<void> Function() {
  (ExitSpy, Future<void> Function()) get spectateExit {
    final spy = ExitSpy();
    Future<void> wrapped() async {
      try {
        await IOOverrides.runZoned(
          this,
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpy1<T0> on void Function(T0) {
  (ExitSpy, void Function(T0)) get spectateExit {
    final spy = ExitSpy();
    void wrapped(T0 a0) {
      try {
        IOOverrides.runZoned(
          () => this(a0),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpyAsync1<T0> on Future<void> Function(T0) {
  (ExitSpy, Future<void> Function(T0)) get spectateExit {
    final spy = ExitSpy();
    Future<void> wrapped(T0 a0) async {
      try {
        await IOOverrides.runZoned(
          () => this(a0),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpy2<T0, T1> on void Function(T0, T1) {
  (ExitSpy, void Function(T0, T1)) get spectateExit {
    final spy = ExitSpy();
    void wrapped(T0 a0, T1 a1) {
      try {
        IOOverrides.runZoned(
          () => this(a0, a1),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpyAsync2<T0, T1> on Future<void> Function(T0, T1) {
  (ExitSpy, Future<void> Function(T0, T1)) get spectateExit {
    final spy = ExitSpy();
    Future<void> wrapped(T0 a0, T1 a1) async {
      try {
        await IOOverrides.runZoned(
          () => this(a0, a1),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpy3<T0, T1, T2> on void Function(T0, T1, T2) {
  (ExitSpy, void Function(T0, T1, T2)) get spectateExit {
    final spy = ExitSpy();
    void wrapped(T0 a0, T1 a1, T2 a2) {
      try {
        IOOverrides.runZoned(
          () => this(a0, a1, a2),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpyAsync3<T0, T1, T2> on Future<void> Function(T0, T1, T2) {
  (ExitSpy, Future<void> Function(T0, T1, T2)) get spectateExit {
    final spy = ExitSpy();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2) async {
      try {
        await IOOverrides.runZoned(
          () => this(a0, a1, a2),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpy4<T0, T1, T2, T3> on void Function(T0, T1, T2, T3) {
  (ExitSpy, void Function(T0, T1, T2, T3)) get spectateExit {
    final spy = ExitSpy();
    void wrapped(T0 a0, T1 a1, T2 a2, T3 a3) {
      try {
        IOOverrides.runZoned(
          () => this(a0, a1, a2, a3),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpyAsync4<T0, T1, T2, T3>
    on Future<void> Function(T0, T1, T2, T3) {
  (ExitSpy, Future<void> Function(T0, T1, T2, T3)) get spectateExit {
    final spy = ExitSpy();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2, T3 a3) async {
      try {
        await IOOverrides.runZoned(
          () => this(a0, a1, a2, a3),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpy5<T0, T1, T2, T3, T4> on void Function(T0, T1, T2, T3, T4) {
  (ExitSpy, void Function(T0, T1, T2, T3, T4)) get spectateExit {
    final spy = ExitSpy();
    void wrapped(T0 a0, T1 a1, T2 a2, T3 a3, T4 a4) {
      try {
        IOOverrides.runZoned(
          () => this(a0, a1, a2, a3, a4),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}

extension ExitSpyAsync5<T0, T1, T2, T3, T4>
    on Future<void> Function(T0, T1, T2, T3, T4) {
  (ExitSpy, Future<void> Function(T0, T1, T2, T3, T4)) get spectateExit {
    final spy = ExitSpy();
    Future<void> wrapped(T0 a0, T1 a1, T2 a2, T3 a3, T4 a4) async {
      try {
        await IOOverrides.runZoned(
          () => this(a0, a1, a2, a3, a4),
          exit: (code) {
            spy._recordExit(code);
            throw ExitException(code);
          },
        );
      } on ExitException {
        // Intercepted exit; return normally.
      }
    }

    return (spy, wrapped);
  }
}
