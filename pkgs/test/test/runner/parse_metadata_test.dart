// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_api/src/backend/platform_selector.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_core/src/runner/parse_metadata.dart';

import 'package:test_core/src/util/io.dart';

String _sandbox;
String _path;

void main() {
  setUp(() {
    _sandbox = createTempDir();
    _path = p.join(_sandbox, 'test.dart');
  });

  tearDown(() {
    Directory(_sandbox).deleteSync(recursive: true);
  });

  test('returns empty metadata for an empty file', () {
    File(_path).writeAsStringSync('');
    var metadata = parseMetadata(_path, Set());
    expect(metadata.testOn, equals(PlatformSelector.all));
    expect(metadata.timeout.scaleFactor, equals(1));
  });

  test('ignores irrelevant annotations', () {
    File(_path).writeAsStringSync('@Fblthp\n@Fblthp.foo\nlibrary foo;');
    var metadata = parseMetadata(_path, Set());
    expect(metadata.testOn, equals(PlatformSelector.all));
  });

  test('parses a prefixed annotation', () {
    File(_path).writeAsStringSync("@foo.TestOn('vm')\n"
        "import 'package:test/test.dart' as foo;");
    var metadata = parseMetadata(_path, Set());
    expect(metadata.testOn.evaluate(SuitePlatform(Runtime.vm)), isTrue);
    expect(metadata.testOn.evaluate(SuitePlatform(Runtime.chrome)), isFalse);
  });

  group('@TestOn:', () {
    test('parses a valid annotation', () {
      File(_path).writeAsStringSync("@TestOn('vm')\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.testOn.evaluate(SuitePlatform(Runtime.vm)), isTrue);
      expect(metadata.testOn.evaluate(SuitePlatform(Runtime.chrome)), isFalse);
    });

    test('ignores a constructor named TestOn', () {
      File(_path).writeAsStringSync("@foo.TestOn('foo')\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.testOn, equals(PlatformSelector.all));
    });

    group('throws an error for', () {
      test('multiple @TestOns', () {
        File(_path)
            .writeAsStringSync("@TestOn('foo')\n@TestOn('bar')\nlibrary foo;");
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });
    });
  });

  group('@Timeout:', () {
    test('parses a valid duration annotation', () {
      File(_path).writeAsStringSync('''
@Timeout(const Duration(
    hours: 1,
    minutes: 2,
    seconds: 3,
    milliseconds: 4,
    microseconds: 5))

library foo;
''');
      var metadata = parseMetadata(_path, Set());
      expect(
          metadata.timeout.duration,
          equals(Duration(
              hours: 1,
              minutes: 2,
              seconds: 3,
              milliseconds: 4,
              microseconds: 5)));
    });

    test('parses a valid duration omitting const', () {
      File(_path).writeAsStringSync('''
@Timeout(Duration(
    hours: 1,
    minutes: 2,
    seconds: 3,
    milliseconds: 4,
    microseconds: 5))

library foo;
''');
      var metadata = parseMetadata(_path, Set());
      expect(
          metadata.timeout.duration,
          equals(Duration(
              hours: 1,
              minutes: 2,
              seconds: 3,
              milliseconds: 4,
              microseconds: 5)));
    });

    test('parses a valid duration with an import prefix', () {
      File(_path).writeAsStringSync('''
@Timeout(core.Duration(
    hours: 1,
    minutes: 2,
    seconds: 3,
    milliseconds: 4,
    microseconds: 5))
import 'dart:core' as core;
''');
      var metadata = parseMetadata(_path, Set());
      expect(
          metadata.timeout.duration,
          equals(Duration(
              hours: 1,
              minutes: 2,
              seconds: 3,
              milliseconds: 4,
              microseconds: 5)));
    });

    test('parses a valid int factor annotation', () {
      File(_path).writeAsStringSync('''
@Timeout.factor(1)

library foo;
''');
      var metadata = parseMetadata(_path, Set());
      expect(metadata.timeout.scaleFactor, equals(1));
    });

    test('parses a valid int factor annotation with an import prefix', () {
      File(_path).writeAsStringSync('''
@test.Timeout.factor(1)
import 'package:test/test.dart' as test;
''');
      var metadata = parseMetadata(_path, Set());
      expect(metadata.timeout.scaleFactor, equals(1));
    });

    test('parses a valid double factor annotation', () {
      File(_path).writeAsStringSync('''
@Timeout.factor(0.5)

library foo;
''');
      var metadata = parseMetadata(_path, Set());
      expect(metadata.timeout.scaleFactor, equals(0.5));
    });

    test('parses a valid Timeout.none annotation', () {
      File(_path).writeAsStringSync('''
@Timeout.none

library foo;
''');
      var metadata = parseMetadata(_path, Set());
      expect(metadata.timeout, same(Timeout.none));
    });

    test('ignores a constructor named Timeout', () {
      File(_path).writeAsStringSync("@foo.Timeout('foo')\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.timeout.scaleFactor, equals(1));
    });

    group('throws an error for', () {
      test('multiple @Timeouts', () {
        File(_path).writeAsStringSync(
            '@Timeout.factor(1)\n@Timeout.factor(2)\nlibrary foo;');
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });
    });
  });

  group('@Skip:', () {
    test('parses a valid annotation', () {
      File(_path).writeAsStringSync('@Skip()\nlibrary foo;');
      var metadata = parseMetadata(_path, Set());
      expect(metadata.skip, isTrue);
      expect(metadata.skipReason, isNull);
    });

    test('parses a valid annotation with a reason', () {
      File(_path).writeAsStringSync("@Skip('reason')\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.skip, isTrue);
      expect(metadata.skipReason, equals('reason'));
    });

    test('ignores a constructor named Skip', () {
      File(_path).writeAsStringSync("@foo.Skip('foo')\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.skip, isFalse);
    });

    group('throws an error for', () {
      test('multiple @Skips', () {
        File(_path)
            .writeAsStringSync("@Skip('foo')\n@Skip('bar')\nlibrary foo;");
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });
    });
  });

  group('@Tags:', () {
    test('parses a valid annotation', () {
      File(_path).writeAsStringSync("@Tags(['a'])\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.tags, equals(['a']));
    });

    test('ignores a constructor named Tags', () {
      File(_path).writeAsStringSync("@foo.Tags(['a'])\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.tags, isEmpty);
    });

    group('throws an error for', () {
      test('multiple @Tags', () {
        File(_path)
            .writeAsStringSync("@Tags(['a'])\n@Tags(['b'])\nlibrary foo;");
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });
    });
  });

  group('@OnPlatform:', () {
    test('parses a valid annotation', () {
      File(_path).writeAsStringSync('''
@OnPlatform({
  'chrome': Timeout.factor(2),
  'vm': [Skip(), Timeout.factor(3)]
})
library foo;''');
      var metadata = parseMetadata(_path, Set());

      var key = metadata.onPlatform.keys.first;
      expect(key.evaluate(SuitePlatform(Runtime.chrome)), isTrue);
      expect(key.evaluate(SuitePlatform(Runtime.vm)), isFalse);
      var value = metadata.onPlatform.values.first;
      expect(value.timeout.scaleFactor, equals(2));

      key = metadata.onPlatform.keys.last;
      expect(key.evaluate(SuitePlatform(Runtime.vm)), isTrue);
      expect(key.evaluate(SuitePlatform(Runtime.chrome)), isFalse);
      value = metadata.onPlatform.values.last;
      expect(value.skip, isTrue);
      expect(value.timeout.scaleFactor, equals(3));
    });

    test('parses a valid annotation with an import prefix', () {
      File(_path).writeAsStringSync('''
@test.OnPlatform({
  'chrome': test.Timeout.factor(2),
  'vm': [test.Skip(), test.Timeout.factor(3)]
})
import 'package:test/test.dart' as test;
''');
      var metadata = parseMetadata(_path, Set());

      var key = metadata.onPlatform.keys.first;
      expect(key.evaluate(SuitePlatform(Runtime.chrome)), isTrue);
      expect(key.evaluate(SuitePlatform(Runtime.vm)), isFalse);
      var value = metadata.onPlatform.values.first;
      expect(value.timeout.scaleFactor, equals(2));

      key = metadata.onPlatform.keys.last;
      expect(key.evaluate(SuitePlatform(Runtime.vm)), isTrue);
      expect(key.evaluate(SuitePlatform(Runtime.chrome)), isFalse);
      value = metadata.onPlatform.values.last;
      expect(value.skip, isTrue);
      expect(value.timeout.scaleFactor, equals(3));
    });

    test('ignores a constructor named OnPlatform', () {
      File(_path).writeAsStringSync("@foo.OnPlatform('foo')\nlibrary foo;");
      var metadata = parseMetadata(_path, Set());
      expect(metadata.testOn, equals(PlatformSelector.all));
    });

    group('throws an error for', () {
      test('a map with a unparseable key', () {
        File(_path).writeAsStringSync(
            "@OnPlatform({'invalid': Skip()})\nlibrary foo;");
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });

      test("a map with an invalid value", () {
        File(_path).writeAsStringSync(
            "@OnPlatform({'vm': const TestOn('vm')})\nlibrary foo;");
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });

      test('a map with an invalid value in a list', () {
        File(_path).writeAsStringSync(
            "@OnPlatform({'vm': [const TestOn('vm')]})\nlibrary foo;");
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });

      test('multiple @OnPlatforms', () {
        File(_path).writeAsStringSync(
            '@OnPlatform({})\n@OnPlatform({})\nlibrary foo;');
        expect(() => parseMetadata(_path, Set()), throwsFormatException);
      });
    });
  });
}
