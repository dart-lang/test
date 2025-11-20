import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

mixin WithTestPackage on AnalysisRuleTest {
  @override
  void setUp() {
    super.setUp();

    var testCorePath = '/packages/test_core';
    newFile('$testCorePath/lib/test_core.dart', '''
void group(
  Object? description,
  dynamic body(), {
  String? testOn,
  Object? /*Timeout?*/ timeout,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
  Object? /*TestLocation?*/ location,
  bool solo = false,
}) {}

void test(
  Object? description,
  dynamic body(), {
  String? testOn,
  Object? /*Timeout?*/ timeout,
  Object? skip,
  Object? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
  Object? /*TestLocation?*/ location,
  bool solo = false,
}) {}
''');
    writeTestPackageConfig(
      PackageConfigFileBuilder()
        ..add(name: 'test_core', rootPath: convertPath(testCorePath)),
    );
  }
}
