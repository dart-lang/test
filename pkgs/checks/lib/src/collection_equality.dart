// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:checks/context.dart';

/// Returns a descriptive `which` for a rejection if the elements of [actual]
/// are unequal to the elements of [expected].
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
Iterable<String>? deepCollectionEquals(Object actual, Object expected) {
  try {
    return _deepCollectionEquals(actual, expected, 0);
  } on _ExceededDepthError {
    return ['exceeds the depth limit of $_maxDepth'];
  }
}

const _maxDepth = 1000;

class _ExceededDepthError extends Error {}

Iterable<String>? _deepCollectionEquals(
    Object actual, Object expected, int depth) {
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
    if (rejectionWhich != null) return rejectionWhich;
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
  return unorderedCompare(
    actual,
    expected,
    (actual, expected) => _elementMatches(actual, expected, depth),
    (expected, _, count) => [
      ...prefixFirst('${path}has no element to match ', literal(expected)),
      if (count > 1) 'or ${count - 1} other elements',
    ],
    (actual, _, count) => [
      ...prefixFirst('${path}has an unexpected element ', literal(actual)),
      if (count > 1) 'and ${count - 1} other unexpected elements',
    ],
  );
}

Iterable<String>? _findMapDifference(
    Object? actual, Map<Object?, Object?> expected, _Path path, int depth) {
  if (actual is! Map) {
    return ['${path}is not a Map'];
  }
  Iterable<String> describeEntry(MapEntry<Object?, Object?> entry) {
    final key = literal(entry.key);
    final value = literal(entry.value);
    return [
      ...key.take(key.length - 1),
      '${key.last}: ${value.first}',
      ...value.skip(1)
    ];
  }

  return unorderedCompare(
    actual.entries,
    expected.entries,
    (actual, expected) =>
        _elementMatches(actual.key, expected.key, depth) &&
        _elementMatches(actual.value, expected.value, depth),
    (expectedEntry, _, count) => [
      ...prefixFirst(
          '${path}has no entry to match ', describeEntry(expectedEntry)),
      if (count > 1) 'or ${count - 1} other entries',
    ],
    (actualEntry, _, count) => [
      ...prefixFirst(
          '${path}has unexpected entry ', describeEntry(actualEntry)),
      if (count > 1) 'and ${count - 1} other unexpected entries',
    ],
  );
}

class _Path {
  final _Path? parent;
  final Object? index;
  _Path._(this.parent, this.index);
  _Path.root()
      : parent = null,
        index = '';
  _Path append(Object? index) => _Path._(this, index);

  @override
  String toString() {
    if (parent == null && index == '') return '';
    final stack = Queue.of([this]);
    var current = parent;
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

/// Returns the `which` for a Rejection if there is no pairing between the
/// elements of [actual] and [expected] using [elementsEqual].
///
/// If there are unmatched expected elements - either actual was too short, or
/// has mismatched elements - returns a rejection reason from calling
/// [unmatchedExpected] with an expected value that could not be paired, it's
/// index, and the count of unmatched elements.
///
/// Otherwise, if there are unmatched actual elements - actual was too long -
/// returns a rejection reason from calling [unmatchedActual] with an actual
/// value that could not be paired, it's index, and the count of unmatched
/// elements.
///
/// Runtime is at least `O(|actual||expected|)`, and for collections with many
/// elements which compare as equal the runtime can reach
/// `O((|actual| + |expected|)^2.5)`.
Iterable<String>? unorderedCompare<T, E>(
    Iterable<T> actual,
    Iterable<E> expected,
    bool Function(T, E) elementsEqual,
    Iterable<String> Function(E, int index, int count) unmatchedExpected,
    Iterable<String> Function(T, int index, int count) unmatchedActual) {
  final indexedExpected = expected.toList();
  final indexedActual = actual.toList();
  final adjacency = <List<int>>[];
  for (int i = 0; i < indexedExpected.length; i++) {
    final expectedElement = indexedExpected[i];
    final pairs = [
      for (var j = 0; j < indexedActual.length; j++)
        if (elementsEqual(indexedActual[j], expectedElement)) j
    ];
    adjacency.add(pairs);
  }
  final unpaired = _findUnpaired(adjacency, indexedActual.length);
  if (unpaired.first.isNotEmpty) {
    final firstUnmatched = indexedExpected[unpaired.first.first];
    return unmatchedExpected(
        firstUnmatched, unpaired.first.first, unpaired.first.length);
  }
  if (unpaired.last.isNotEmpty) {
    final firstUnmatched = indexedActual[unpaired.last.first];
    return unmatchedActual(
        firstUnmatched, unpaired.last.first, unpaired.last.length);
  }
  return null;
}

/// Returns the indices which are unmatched in an optimal pairing in the
/// bipartite graph represented by [adjacency].
///
/// Vertices are represented as integers. The two sets of vertices (`U` and `V`)
/// in the biparte graph are represented as:
/// - `U` - the indices of [adjacency].
/// - `V` - values smaller than [rightVertexCount].
///
/// An edge from `U[n]` to `V[m]` is represented by the value `m` being present
/// in the list at index `n`.
/// The largest value within any list in [adjacency] must be smaller than
/// [rightVertexCount].
///
/// Returns a List with two values, the unpaired values of `U` and `V` in the
/// maximum-caridnality matching betweeen them.
///
/// If there is a perfect pairing, the returned lists will both be empty.
///
/// Uses the Hopcroft–Karp algorithm based on pseudocode from
/// https://en.wikipedia.org/wiki/Hopcroft%E2%80%93Karp_algorithm
List<List<int>> _findUnpaired(List<List<int>> adjacency, int rightVertexCount) {
  final leftLength = adjacency.length;
  final rightLength = rightVertexCount;
  // The last index represents a "dummy vertex"
  final distances = List<num>.filled(leftLength + 1, double.infinity);
  // Initially everything is paired with the "dummy vertex" of the opposite set
  final leftPairs = List.filled(leftLength, rightLength);
  final rightPairs = List.filled(rightLength, leftLength);

  bool bfs() {
    final queue = Queue<int>();
    for (int leftIndex = 0; leftIndex < leftLength; leftIndex++) {
      if (leftPairs[leftIndex] == rightLength) {
        distances[leftIndex] = 0;
        queue.add(leftIndex);
      } else {
        distances[leftIndex] = double.infinity;
      }
    }
    distances.last = double.infinity;
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (distances[current] < distances[leftLength]) {
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
    if (leftIndex == leftLength) return true;
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

  while (bfs()) {
    for (int leftIndex = 0; leftIndex < leftLength; leftIndex++) {
      if (leftPairs[leftIndex] == rightLength) {
        dfs(leftIndex);
      }
    }
  }
  return [
    [
      for (int i = 0; i < leftLength; i++)
        if (leftPairs[i] == rightLength) i
    ],
    [
      for (int i = 0; i < rightLength; i++)
        if (rightPairs[i] == leftLength) i
    ]
  ];
}
