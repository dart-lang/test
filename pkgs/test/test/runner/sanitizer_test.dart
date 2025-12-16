// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm && linux')
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  String? skipReason;
  if (!File('$sdkDir/bin/dartaotruntime_asan').existsSync()) {
    skipReason = 'SDK too old';
  }

  test('asan success', () async {
    final testSource = '''
@TestOn('vm-asan')
library asan_environment_test;

import 'package:test/test.dart';

void main() {
  test('const', () {
    // I.e., correct during kernel compilation.
    expect(const bool.fromEnvironment("dart.vm.asan"), equals(true));

    expect(const bool.fromEnvironment("dart.vm.msan"), equals(false));
    expect(const bool.fromEnvironment("dart.vm.tsan"), equals(false));
  });

  test('new', () {
    // I.e., correct during VM lookup.
    expect(new bool.fromEnvironment("dart.vm.asan"), equals(true));

    expect(new bool.fromEnvironment("dart.vm.msan"), equals(false));
    expect(new bool.fromEnvironment("dart.vm.tsan"), equals(false));
  });
}
''';

    await d.file('test.dart', testSource).create();
    var test = await runTest(['test.dart', '-p', 'vm-asan']);

    expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
    await test.shouldExit(0);
  }, skip: skipReason);

  test('asan failure', () async {
    final testSource = '''
@TestOn('vm-asan')
library asan_test;

import 'package:test/test.dart';
import 'dart:ffi';

@Native<Pointer Function(IntPtr)>(symbol: 'malloc')
external Pointer malloc(int size);
@Native<Void Function(Pointer)>(symbol: 'free')
external void free(Pointer ptr);
@Native<Void Function(Pointer, Int, Size)>(symbol: 'memset')
external void memset(Pointer ptr, int char, int size);

void main() {
  test('use-after-free', () {
    var p = malloc(sizeOf<Long>()).cast<Long>();
    free(p);
    memset(p, 42, sizeOf<Long>());  // ASAN: heap-use-after-free
  });
}
''';

    await d.file('test.dart', testSource).create();
    var test = await runTest(['test.dart', '-p', 'vm-asan']);

    expect(
      test.stderr,
      emitsThrough(contains('AddressSanitizer: heap-use-after-free')),
    );
    await test.shouldExit(6);
  }, skip: skipReason);

  test('msan success', () async {
    final testSource = '''
@TestOn('vm-msan')
library msan_environment_test;

import 'package:test/test.dart';

void main() {
  test('const', () {
    // I.e., correct during kernel compilation.
    expect(const bool.fromEnvironment("dart.vm.msan"), equals(true));

    expect(const bool.fromEnvironment("dart.vm.asan"), equals(false));
    expect(const bool.fromEnvironment("dart.vm.tsan"), equals(false));
  });

  test('new', () {
    // I.e., correct during VM lookup.
    expect(new bool.fromEnvironment("dart.vm.msan"), equals(true));

    expect(new bool.fromEnvironment("dart.vm.asan"), equals(false));
    expect(new bool.fromEnvironment("dart.vm.tsan"), equals(false));
  });
}
''';

    await d.file('test.dart', testSource).create();
    var test = await runTest(['test.dart', '-p', 'vm-msan']);

    expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
    await test.shouldExit(0);
  }, skip: skipReason);

  test('msan failure', () async {
    final testSource = '''
@TestOn('vm-msan')
library msan_test;

import 'dart:ffi';
import 'package:test/test.dart';

@Native<Pointer Function(IntPtr)>(symbol: 'malloc')
external Pointer malloc(int size);
@Native<Void Function(Pointer)>(symbol: 'free')
external void free(Pointer ptr);
@Native<Void Function(Pointer, Pointer, Size)>(symbol: 'memcmp')
external void memcmp(Pointer a, Pointer b, int size);

void main() {
  test('uninitialized', () {
    var a = malloc(8);
    var b = malloc(8);
    memcmp(a, b, 8);  // MSAN: use-of-uninitialized-value
    free(b);
    free(a);
  });
}
''';

    await d.file('test.dart', testSource).create();
    var test = await runTest(['test.dart', '-p', 'vm-msan']);

    expect(
      test.stderr,
      emitsThrough(contains('MemorySanitizer: use-of-uninitialized-value')),
    );
    await test.shouldExit(6);
  }, skip: skipReason);

  test('tsan success', () async {
    final testSource = '''
@TestOn('vm-tsan')
library tsan_environment_test;

import 'package:test/test.dart';

void main() {
  test('const', () {
    // I.e., correct during kernel compilation.
    expect(const bool.fromEnvironment("dart.vm.tsan"), equals(true));

    expect(const bool.fromEnvironment("dart.vm.asan"), equals(false));
    expect(const bool.fromEnvironment("dart.vm.msan"), equals(false));
  });

  test('new', () {
    // I.e., correct during VM lookup.
    expect(new bool.fromEnvironment("dart.vm.tsan"), equals(true));

    expect(new bool.fromEnvironment("dart.vm.asan"), equals(false));
    expect(new bool.fromEnvironment("dart.vm.msan"), equals(false));
  });
}
''';

    await d.file('test.dart', testSource).create();
    var test = await runTest(['test.dart', '-p', 'vm-tsan']);

    expect(test.stdout, emitsThrough(contains('+2: All tests passed!')));
    await test.shouldExit(0);
  }, skip: skipReason);

  test('tsan failure', () async {
    final testSource = '''
@TestOn('vm-tsan')
library tsan_test;

import 'dart:ffi';
import 'dart:isolate';
import 'package:test/test.dart';

@Native<Pointer Function(IntPtr)>(symbol: 'malloc')
external Pointer malloc(int size);
@Native<Void Function(Pointer)>(symbol: 'free')
external void free(Pointer ptr);
@Native<Void Function(Pointer, Int, Size)>(symbol: 'memset', isLeaf: true)
external void memset_leaf(Pointer ptr, int char, int size);
@Native<Void Function(IntPtr)>(symbol: 'usleep', isLeaf: true)
external void usleep_leaf(int useconds);

child(addr) {
  var p = Pointer<IntPtr>.fromAddress(addr);
  for (var i = 0; i < 50000; i++) {
    memset_leaf(p, 42, sizeOf<IntPtr>()); // TSAN: data race
    usleep_leaf(100);
  }
}

void main() {
  test('data race', () async {
    var p = malloc(sizeOf<IntPtr>()).cast<IntPtr>();
    var f = Isolate.run(() => child(p.address));

    for (var i = 0; i < 50000; i++) {
      p[0] = p[0] + 1; // TSAN: data race
      usleep_leaf(100);
    }

    await f;
    free(p);
  });
}
''';

    await d.file('test.dart', testSource).create();
    var test = await runTest(['test.dart', '-p', 'vm-tsan']);

    expect(test.stderr, emitsThrough(contains('ThreadSanitizer: data race')));
    await test.shouldExit(6);
  }, skip: skipReason);
}
