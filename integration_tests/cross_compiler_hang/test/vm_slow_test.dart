@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:test/test.dart';

void main() {
  test('slow compile vm exe test', () {
    expect(AnalysisContext, isNotNull);
  });
}
