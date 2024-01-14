// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import 'test_failure.dart';

/// An exception that was thrown remotely.
///
/// This could be an exception thrown in a different isolate, a different
/// process, or on an entirely different computer.
final class RemoteException implements Exception {
  /// The original exception's message, if it had one.
  ///
  /// If the original exception was a plain string, this will contain that
  /// string.
  final String? message;

  /// The value of the original exception's `runtimeType.toString()`.
  final String type;

  /// The value of the original exception's `toString()`.
  final String _toString;

  /// Serializes [error] and [stackTrace] into a JSON-safe object.
  ///
  /// Other than JSON- and isolate-safety, no guarantees are made about the
  /// serialized format.
  static Map<String, dynamic> serialize(dynamic error, StackTrace stackTrace) {
    String? message;
    if (error is String) {
      message = error;
    } else {
      try {
        message = error.message.toString();
      } on NoSuchMethodError catch (_) {
        // Do nothing.
      }
    }

    final supertype = (error is TestFailure) ? 'TestFailure' : null;

    return {
      'message': message,
      'type': error.runtimeType.toString(),
      'supertype': supertype,
      'toString': error.toString(),
      'stackChain': Chain.forTrace(stackTrace).toString()
    };
  }

  /// Deserializes an exception serialized with [RemoteException.serialize].
  ///
  /// The returned [AsyncError] is guaranteed to have a [RemoteException] as its
  /// error and a [Chain] as its stack trace.
  static AsyncError deserialize(Map serialized) {
    return AsyncError(_deserializeException(serialized),
        Chain.parse(serialized['stackChain'] as String));
  }

  /// Deserializes the exception portion of [serialized].
  static RemoteException _deserializeException(Map serialized) {
    final message = serialized['message'] as String?;
    final type = serialized['type'] as String;
    final toString = serialized['toString'] as String;

    return switch (serialized['supertype'] as String?) {
      'TestFailure' => _RemoteTestFailure(message, type, toString),
      _ => RemoteException._(message, type, toString),
    };
  }

  RemoteException._(this.message, this.type, this._toString);

  @override
  String toString() => _toString;
}

/// A subclass of [RemoteException] that implements [TestFailure].
///
/// It's important to preserve [TestFailure]-ness, because tests have different
/// results depending on whether an exception was a failure or an error.
final class _RemoteTestFailure extends RemoteException implements TestFailure {
  _RemoteTestFailure(super.message, super.type, super.toString) : super._();
}
