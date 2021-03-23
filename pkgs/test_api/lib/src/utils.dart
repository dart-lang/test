// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A regular expression matching a hyphenated identifier.
///
/// This is like a standard Dart identifier, except that it can also contain
/// hyphens.
final _hyphenatedIdentifier = RegExp(r'[a-zA-Z_-][a-zA-Z0-9_-]*');

/// Like [_hyphenatedIdentifier], but anchored so that it must match the entire
/// string.
final anchoredHyphenatedIdentifier =
    RegExp('^${_hyphenatedIdentifier.pattern}\$');

/// Throws an [ArgumentError] if [message] isn't recursively JSON-safe.
void ensureJsonEncodable(Object? message) {
  if (message == null ||
      message is String ||
      message is num ||
      message is bool) {
    // JSON-encodable, hooray!
  } else if (message is List) {
    for (var element in message) {
      ensureJsonEncodable(element);
    }
  } else if (message is Map) {
    message.forEach((key, value) {
      if (key is! String) {
        throw ArgumentError("$message can't be JSON-encoded.");
      }

      ensureJsonEncodable(value);
    });
  } else {
    throw ArgumentError.value("$message can't be JSON-encoded.");
  }
}
