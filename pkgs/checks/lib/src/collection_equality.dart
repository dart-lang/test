// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:checks/context.dart';

/// Returns a rejection if the elements of [actual] are unequal to the elements
/// of [expected].
///
/// {@template deep_collection_equals}
/// Elements, keys, or values, which are a collections are deeply compared for
/// equality, and do not use the native identity based equality or custom
/// equality operator overrides.
/// Elements, keys, or values, which are a [Condition] instances are checked
/// against actual values.
/// All other value or key types use `operator ==`.
///
/// Comparing sets or maps will have a runtime which is polynomial on the the
/// size of those collections. Does not use [Set.contains] or [Map.containsKey],
/// there will not be runtime benefits from hashing. Custom collection behavior
/// is ignored. For example, it is not possible to distinguish between a `Set`
/// and a `Set.identity`.
///
/// Collections may be nested to a maximum depth of 1000. Recursive collections
/// are not allowed.
/// {@endtemplate}
Rejection? deepCollectionEquals(Object actual, Object expected) {
  try {
    return _deepCollectionEquals(actual, expected, 0);
  } on _ExceededDepthError {
    return Rejection(
        actual: literal(actual),
        which: ['exceeds the depth limit of $_maxDepth']);
  }
}

const _maxDepth = 1000;

class _ExceededDepthError extends Error {}

Rejection? _deepCollectionEquals(Object actual, Object expected, int depth) {
  assert(actual is Iterable || actual is Map);
  assert(expected is Iterable || expected is Map);

  final queue = Queue.of([_Search(_Path.root(), actual, expected, depth)]);
  while (queue.isNotEmpty) {
    final toCheck = queue.removeFirst();
    final currentActual = toCheck.actual;
    final currentExpected = toCheck.expected;
    final path = toCheck.path;
    final currentDepth = toCheck.depth;
    Iterable<String>? rejectionWhich;
    if (currentExpected is Set) {
      rejectionWhich = _findSetDifference(
          currentActual, currentExpected, path, currentDepth);
    } else if (currentExpected is Iterable) {
      rejectionWhich = _findIterableDifference(
          currentActual, currentExpected, path, queue, currentDepth);
    } else {
      currentExpected as Map;
      rejectionWhich = _findMapDifference(
          currentActual, currentExpected, path, currentDepth);
    }
    if (rejectionWhich != null) {
      return Rejection(actual: literal(actual), which: rejectionWhich);
    }
  }
  return null;
}

List<String>? _findIterableDifference(Object? actual,
    Iterable<Object?> expected, _Path path, Queue<_Search> queue, int depth) {
  if (actual is! Iterable) {
    return ['${path}is not an Iterable'];
  }
  var actualIterator = actual.iterator;
  var expectedIterator = expected.iterator;
  for (var index = 0;; index++) {
    var actualNext = actualIterator.moveNext();
    var expectedNext = expectedIterator.moveNext();
    if (!expectedNext && !actualNext) break;
    if (!expectedNext) {
      return [
        '${path}has more elements than expected',
        'expected an iterable with $index element(s)'
      ];
    }
    if (!actualNext) {
      return [
        '${path}has too few elements',
        'expected an iterable with at least ${index + 1} element(s)'
      ];
    }
    var actualValue = actualIterator.current;
    var expectedValue = expectedIterator.current;
    if (expectedValue is Iterable || expectedValue is Map) {
      if (depth + 1 > _maxDepth) throw _ExceededDepthError();
      queue.addLast(
          _Search(path.append(index), actualValue, expectedValue, depth + 1));
    } else if (expectedValue is Condition) {
      final failure = softCheck(actualValue, expectedValue);
      if (failure != null) {
        final which = failure.rejection.which;
        return [
          'has an element ${path.append(index)}that:',
          ...indent(failure.detail.actual.skip(1)),
          ...indent(prefixFirst('Actual: ', failure.rejection.actual),
              failure.detail.depth + 1),
          if (which != null)
            ...indent(prefixFirst('which ', which), failure.detail.depth + 1)
        ];
      }
    } else {
      if (actualValue != expectedValue) {
        return [
          ...prefixFirst('${path.append(index)}is ', literal(actualValue)),
          ...prefixFirst('which does not equal ', literal(expectedValue))
        ];
      }
    }
  }
  return null;
}

bool _elementMatches(Object? actual, Object? expected, int depth) {
  if (expected == null) return actual == null;
  if (expected is Iterable || expected is Map) {
    if (++depth > _maxDepth) throw _ExceededDepthError();
    return actual != null &&
        _deepCollectionEquals(actual, expected, depth) == null;
  }
  if (expected is Condition) {
    return softCheck(actual, expected) == null;
  }
  return expected == actual;
}

Iterable<String>? _findSetDifference(
    Object? actual, Set<Object?> expected, _Path path, int depth) {
  if (actual is! Set) {
    return ['${path}is not a Set'];
  }
  final indexedExpected = expected.toList();
  final indexedActual = actual.toList();
  final adjacency = <List<int>>[];

  for (final expectedElement in indexedExpected) {
    final pairs = [
      for (var j = 0; j < indexedActual.length; j++)
        if (_elementMatches(indexedActual[j], expectedElement, depth)) j,
    ];
    if (pairs.isEmpty) {
      return prefixFirst(
          '${path}has no element to match ', literal(expectedElement));
    }
    adjacency.add(pairs);
  }
  if (indexedActual.length != indexedExpected.length) {
    return [
      '${path}has ${indexedActual.length} element(s),',
      'expected a set with ${indexedExpected.length} element(s)'
    ];
  }
  if (!_hasPerfectMatching(adjacency)) {
    return prefixFirst(
        '${path}cannot be matched with the elements of ', literal(expected));
  }
  return null;
}

Iterable<String>? _findMapDifference(
    Object? actual, Map<Object?, Object?> expected, _Path path, int depth) {
  if (actual is! Map) {
    return ['${path}is not a Map'];
  }
  final expectedEntries = expected.entries.toList();
  final actualEntries = actual.entries.toList();
  final adjacency = <List<int>>[];
  for (final expectedEntry in expectedEntries) {
    final potentialPairs = [
      for (var i = 0; i < actualEntries.length; i++)
        if (_elementMatches(actualEntries[i].key, expectedEntry.key, depth)) i
    ];
    if (potentialPairs.isEmpty) {
      return prefixFirst(
          '${path}has no key to match ', literal(expectedEntry.key));
    }
    final matchingPairs = [
      for (var i in potentialPairs)
        if (_elementMatches(actualEntries[i].value, expectedEntry.value, depth))
          i
    ];
    if (matchingPairs.isEmpty) {
      return prefixFirst(
          '${path.append(expectedEntry.key)}has no value to match ',
          literal(expectedEntry.value));
    }
    adjacency.add(matchingPairs);
  }
  if (expectedEntries.length != actualEntries.length) {
    return [
      '${path}has ${actualEntries.length} entries,',
      'expected a Map with ${expectedEntries.length} entries'
    ];
  }
  if (!_hasPerfectMatching(adjacency)) {
    return prefixFirst(
        '${path}cannot be matched with the entries of ', literal(expected));
  }
  return null;
}

class _Path {
  final _Path? parent;
  final Object? index;
  _Path._(this.parent, this.index);
  _Path.root()
      : parent = null,
        index = '';
  _Path append(Object? index) => _Path._(this, index);
  String toString() {
    if (parent == null && index == '') return '';
    final stack = Queue.of([this]);
    var current = this.parent;
    while (current?.parent != null) {
      stack.addLast(current!);
      current = current.parent;
    }
    final result = StringBuffer('at ');
    while (stack.isNotEmpty) {
      result.write('[');
      result.write(literal(stack.removeLast().index).join(r'\n'));
      result.write(']');
    }
    result.write(' ');
    return result.toString();
  }
}

class _Search {
  final _Path path;
  final Object? actual;
  final Object? expected;
  final int depth;
  _Search(this.path, this.actual, this.expected, this.depth);
}

/// Returns true if [adjacency] represents a bipartite graph that has a perfect
/// pairing without unpaired elements in either set.
///
/// Vertices are represented as integers - a vertice in `u` is an index in
/// [adjacency], and a vertice in `v` is a value in list at that index. An edge
/// from `U[n]` to `V[m]` is represented by the value `m` being present in the
/// list at index `n`.
/// Assumes that there are an equal number of values in both sets, equal to the
/// length of [adjacency].
///
/// Uses the Hopcroft–Karp algorithm based on pseudocode from
/// https://en.wikipedia.org/wiki/Hopcroft%E2%80%93Karp_algorithm
bool _hasPerfectMatching(List<List<int>> adjacency) {
  final length = adjacency.length;
  // The index [length] represents a "dummy vertex"
  final distances = List<num>.filled(length + 1, double.infinity);
  // Initially, everything is paired with the "dummy vertex"
  final leftPairs = List.filled(length, length);
  final rightPairs = List.filled(length, length);
  bool bfs() {
    final queue = Queue<int>();
    for (int leftIndex = 0; leftIndex < length; leftIndex++) {
      if (leftPairs[leftIndex] == length) {
        distances[leftIndex] = 0;
        queue.add(leftIndex);
      } else {
        distances[leftIndex] = double.infinity;
      }
    }
    distances.last = double.infinity;
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (distances[current] < distances[length]) {
        for (final rightIndex in adjacency[current]) {
          if (distances[rightPairs[rightIndex]].isInfinite) {
            distances[rightPairs[rightIndex]] = distances[current] + 1;
            queue.addLast(rightPairs[rightIndex]);
          }
        }
      }
    }
    return !distances.last.isInfinite;
  }

  bool dfs(int leftIndex) {
    if (leftIndex == length) return true;
    for (final rightIndex in adjacency[leftIndex]) {
      if (distances[rightPairs[rightIndex]] == distances[leftIndex] + 1) {
        if (dfs(rightPairs[rightIndex])) {
          leftPairs[leftIndex] = rightIndex;
          rightPairs[rightIndex] = leftIndex;
          return true;
        }
      }
    }
    distances[leftIndex] = double.infinity;
    return false;
  }

  var matching = 0;
  while (bfs()) {
    for (int leftIndex = 0; leftIndex < length; leftIndex++) {
      if (leftPairs[leftIndex] == length) {
        if (dfs(leftIndex)) {
          matching++;
        }
      }
    }
  }
  return matching == length;
}
