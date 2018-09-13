import '../backend/runtime.dart';
import '../backend/suite_platform.dart';

SuitePlatform currentPlatform(Runtime runtime) => throw UnsupportedError(
    'Getting the current platform is only supported where dart:io exists');
