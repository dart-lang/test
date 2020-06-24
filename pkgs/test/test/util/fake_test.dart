// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore: deprecated_member_use
@TestOn('vm')
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  _FakeSample fake;
  setUp(() {
    fake = _FakeSample();
  });
  test('method invocation', () {
    expect(
        () => fake.f(),
        throwsA(isTestFailure(
            'Symbol("f") invoked on fake object of type _FakeSample')));
  });
  test('getter', () {
    expect(
        () => fake.x,
        throwsA(isTestFailure(
            'Symbol("x") invoked on fake object of type _FakeSample')));
  });
  test('setter', () {
    expect(
        () => fake.x = 0,
        throwsA(isTestFailure(
            'Symbol("x=") invoked on fake object of type _FakeSample')));
  });
  test('operator', () {
    expect(
        () => fake + 1,
        throwsA(isTestFailure(
            'Symbol("+") invoked on fake object of type _FakeSample')));
  });
  test('==', () {
    expect(
        () => fake == Object(),
        throwsA(isTestFailure(
            'Symbol("==") invoked on fake object of type _FakeSample')));
  });
  test('hashCode', () {
    expect(
        () => fake.hashCode,
        throwsA(isTestFailure(
            'Symbol("hashCode") invoked on fake object of type _FakeSample')));
  });
  test('runtimeType', () {
    expect(
        () => fake.runtimeType,
        throwsA(isTestFailure(
            'Symbol("runtimeType") invoked on fake object of type _FakeSample')));
  });
}

class _Sample {
  void f() {}

  int get x => 0;

  void set x(int value) {}

  int operator +(int other) => 0;
}

class _FakeSample extends Fake implements _Sample {}
