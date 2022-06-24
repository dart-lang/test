import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:test/test.dart';

Matcher isARejection({Object? which, Object? actual}) {
  var rejection = isA<Rejection>().having((p0) => p0.which, 'which', which);

  rejection = rejection.having((p0) => p0.actual, 'actual', actual);

  return rejection;
}

void main() {
  group('TypeChecks', () {
    test('isA', () {
      checkThat(1).isA<int>();

      expect(
        softCheck(1, (p0) => p0.isA<String>()),
        isARejection(actual: '<1>', which: ['Is a int']),
      );
    });
  });

  group('HasField', () {
    test('has', () {
      checkThat(1).has((v) => v.isOdd, 'isOdd').isTrue();

      expect(
        softCheck<int>(
          2,
          (p0) => p0.has((v) => throw UnimplementedError(), 'isOdd'),
        ),
        isARejection(
          actual: '<2>',
          which: ['threw while trying to read property'],
        ),
      );
    });

    test('that', () {
      checkThat(true).that((p0) => p0.isTrue());
    });

    test('not', () {
      checkThat(false).not((p0) => p0.isTrue());

      expect(
        softCheck<bool>(
          true,
          (p0) => p0.not((p0) => p0.isTrue()),
        ),
        isARejection(
          actual: '<true>',
          which: ['is a value that: ', '    is true'],
        ),
      );
    });
  });

  group('BoolChecks', () {
    test('isTrue', () {
      checkThat(true).isTrue();

      expect(
        softCheck<bool>(
          false,
          (p0) => p0.isTrue(),
        ),
        isARejection(actual: '<false>'),
      );
    });

    test('isFalse', () {
      checkThat(false).isFalse();

      expect(
        softCheck<bool>(
          true,
          (p0) => p0.isFalse(),
        ),
        isARejection(actual: '<true>'),
      );
    });
  });

  group('EqualityChecks', () {
    test('equals', () {
      checkThat(1).equals(1);

      expect(
        softCheck(1, (p0) => p0.equals(2)),
        isARejection(actual: '<1>', which: ['are not equal']),
      );
    });

    test('identical', () {
      checkThat(1).identicalTo(1);

      expect(
        softCheck(1, (p0) => p0.identicalTo(2)),
        isARejection(actual: '<1>', which: ['is not identical']),
      );
    });
  });

  group('NullabilityChecks', () {
    test('isNotNull', () {
      checkThat(1).isNotNull();

      expect(
        softCheck(null, (p0) => p0.isNotNull()),
        isARejection(actual: '<null>'),
      );
    });

    test('isNull', () {
      checkThat(null).isNull();

      expect(
        softCheck(1, (p0) => p0.isNull()),
        isARejection(actual: '<1>'),
      );
    });
  });

  group('StringChecks', () {
    test('contains', () {
      checkThat('bob').contains('bo');
      expect(
        softCheck<String>('bob', (p0) => p0.contains('kayleb')),
        isARejection(actual: "'bob'", which: ["Does not contain 'kayleb'"]),
      );
    });
    test('length', () {
      checkThat('bob').length.equals(3);
    });
    test('isEmpty', () {
      checkThat('').isEmpty();
      expect(
        softCheck<String>('bob', (p0) => p0.isEmpty()),
        isARejection(actual: "'bob'", which: ['is not empty']),
      );
    });
    test('isNotEmpty', () {
      checkThat('bob').isNotEmpty();
      expect(
        softCheck<String>('', (p0) => p0.isNotEmpty()),
        isARejection(actual: "''", which: ['is empty']),
      );
    });
    test('startsWith', () {
      checkThat('bob').startsWith('bo');
      expect(
        softCheck<String>('bob', (p0) => p0.startsWith('kayleb')),
        isARejection(actual: "'bob'", which: ["does not start with 'kayleb'"]),
      );
    });
    test('endsWith', () {
      checkThat('bob').endsWith('ob');
      expect(
        softCheck<String>('bob', (p0) => p0.endsWith('kayleb')),
        isARejection(actual: "'bob'", which: ["does not end with 'kayleb'"]),
      );
    });
  });
}
