import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('TypeChecks', () {
    test('isA', () {
      checkThat(1).isA<int>();

      checkThat(
        softCheck(1, (p0) => p0.isA<String>()),
      ).isARejection(actual: '<1>', which: ['Is a int']);
    });
  });

  group('HasField', () {
    test('has', () {
      checkThat(1).has((v) => v.isOdd, 'isOdd').isTrue();

      checkThat(
        softCheck<int>(
          2,
          (p0) => p0.has((v) => throw UnimplementedError(), 'isOdd'),
        ),
      ).isARejection(
        actual: '<2>',
        which: ['threw while trying to read property'],
      );
    });

    test('that', () {
      checkThat(true).that((p0) => p0.isTrue());
    });

    test('not', () {
      checkThat(false).not((p0) => p0.isTrue());

      checkThat(
        softCheck<bool>(
          true,
          (p0) => p0.not((p0) => p0.isTrue()),
        ),
      ).isARejection(
        actual: '<true>',
        which: ['is a value that: ', '    is true'],
      );
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      checkThat(true).isTrue();

      checkThat(
        softCheck<bool>(
          false,
          (p0) => p0.isTrue(),
        ),
      ).isARejection(actual: '<false>');
    });

    test('isFalse', () {
      checkThat(false).isFalse();

      checkThat(softCheck<bool>(
        true,
        (p0) => p0.isFalse(),
      )).isARejection(actual: '<true>');
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      checkThat(1).equals(1);

      checkThat(
        softCheck(1, (p0) => p0.equals(2)),
      ).isARejection(actual: '<1>', which: ['are not equal']);
    });

    test('identical', () {
      checkThat(1).identicalTo(1);

      checkThat(softCheck(1, (p0) => p0.identicalTo(2)))
          .isARejection(actual: '<1>', which: ['is not identical']);
    });
  });

  group('NullabilityChecks', () {
    test('isNotNull', () {
      checkThat(1).isNotNull();

      checkThat(softCheck(null, (p0) => p0.isNotNull()))
          .isARejection(actual: '<null>');
    });

    test('isNull', () {
      checkThat(null).isNull();

      checkThat(softCheck(1, (p0) => p0.isNull())).isARejection(actual: '<1>');
    });
  });

  group('StringChecks', () {
    test('contains', () {
      checkThat('bob').contains('bo');
      checkThat(
        softCheck<String>('bob', (p0) => p0.contains('kayleb')),
      ).isARejection(actual: "'bob'", which: ["Does not contain 'kayleb'"]);
    });
    test('length', () {
      checkThat('bob').length.equals(3);
    });
    test('isEmpty', () {
      checkThat('').isEmpty();
      checkThat(
        softCheck<String>('bob', (p0) => p0.isEmpty()),
      ).isARejection(actual: "'bob'", which: ['is not empty']);
    });
    test('isNotEmpty', () {
      checkThat('bob').isNotEmpty();
      checkThat(
        softCheck<String>('', (p0) => p0.isNotEmpty()),
      ).isARejection(actual: "''", which: ['is empty']);
    });
    test('startsWith', () {
      checkThat('bob').startsWith('bo');
      checkThat(
        softCheck<String>('bob', (p0) => p0.startsWith('kayleb')),
      ).isARejection(actual: "'bob'", which: ["does not start with 'kayleb'"]);
    });
    test('endsWith', () {
      checkThat('bob').endsWith('ob');
      checkThat(softCheck<String>('bob', (p0) => p0.endsWith('kayleb')))
          .isARejection(actual: "'bob'", which: ["does not end with 'kayleb'"]);
    });
  });
}

extension on Check<Iterable<String>?> {
  // TODO: remove this once we have a deepEquals or equivalent
  void toStringEquals(List<String>? other) {
    final otherToString = other.toString();
    context.expect(() => ['toString equals'], (actual) {
      final actualToString = actual.toString();
      return actual.toString() == otherToString
          ? null
          : Rejection(actual: actualToString);
    });
  }
}

extension on Check<Rejection?> {
  void isARejection({List<String>? which, required String actual}) {
    this.isNotNull()
      ..has((p0) => p0.actual, 'actual').equals(actual)
      ..has((p0) => p0.which, 'which').toStringEquals(which);
  }
}
