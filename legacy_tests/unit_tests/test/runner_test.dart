import 'dart:convert';
import 'dart:isolate';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'io.dart';

void main() {
  setUpAll(precompileTestExecutable);

  group('nnbd', () {
    final testContents = '''
import 'package:test/test.dart';
import 'opted_out.dart';

void main() {
  test("success", () {
    expect(foo, true);
  });
}''';

    setUp(() async {
      await d.file('opted_out.dart', '''
// @dart=2.8
final foo = true;''').create();
    });

    test('sound null safety is enabled if the entrypoint opts in explicitly',
        () async {
      await d.file('test.dart', '''
// @dart=2.12
$testContents
''').create();
      var test = await runTest(['test.dart']);

      expect(
          test.stdout,
          emitsThrough(contains(
              'Error: A library can\'t opt out of null safety by default, '
              'when using sound null safety.')));
      await test.shouldExit(1);
    });

    test('sound null safety is disabled if the entrypoint opts out explicitly',
        () async {
      await d.file('test.dart', '''
// @dart=2.8
$testContents''').create();
      var test = await runTest(['test.dart']);

      expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
      await test.shouldExit(0);
    });

    group('defaults', () {
      late PackageConfig currentPackageConfig;

      setUpAll(() async {
        currentPackageConfig =
            await loadPackageConfigUri((await Isolate.packageConfig)!);
      });

      setUp(() async {
        await d.file('test.dart', testContents).create();
      });

      test('sound null safety is enabled if the package is opted in', () async {
        var newPackageConfig = PackageConfig([
          ...currentPackageConfig.packages,
          Package('example', Uri.file('${d.sandbox}/'),
              languageVersion: LanguageVersion(2, 12),
              // TODO: https://github.com/dart-lang/package_config/issues/81
              packageUriRoot: Uri.file('${d.sandbox}/')),
        ]);

        await d
            .file('package_config.json',
                jsonEncode(PackageConfig.toJson(newPackageConfig)))
            .create();

        var test = await runTest(['test.dart'],
            packageConfig: p.join(d.sandbox, 'package_config.json'));

        expect(
            test.stdout,
            emitsThrough(contains(
                'Error: A library can\'t opt out of null safety by default, '
                'when using sound null safety.')));
        await test.shouldExit(1);
      });

      test('sound null safety is disabled if the package is opted out',
          () async {
        var newPackageConfig = PackageConfig([
          ...currentPackageConfig.packages,
          Package('example', Uri.file('${d.sandbox}/'),
              languageVersion: LanguageVersion(2, 8),
              // TODO: https://github.com/dart-lang/package_config/issues/81
              packageUriRoot: Uri.file('${d.sandbox}/')),
        ]);

        await d
            .file('package_config.json',
                jsonEncode(PackageConfig.toJson(newPackageConfig)))
            .create();

        var test = await runTest(['test.dart'],
            packageConfig: p.join(d.sandbox, 'package_config.json'));

        expect(test.stdout, emitsThrough(contains('+1: All tests passed!')));
        await test.shouldExit(0);
      });
    });
  });
}
