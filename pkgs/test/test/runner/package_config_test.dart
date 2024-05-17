import 'package:test/test.dart';

void main() {
  test('rootPackageConfig is defined', () {
    print(String.fromEnvironment('ROOT_PACKAGE_CONFIG'));
    expect(String.fromEnvironment('ROOT_PACKAGE_CONFIG'), isNotEmpty);
  });
}
