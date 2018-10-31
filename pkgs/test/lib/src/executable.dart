// ignore: implementation_imports
import 'package:test_core/src/executable.dart' as executable;
import 'package:test_core/src/runner/hack_register_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'runner/node/platform.dart';
import 'runner/browser/platform.dart';

main(List<String> args) async {
  registerPlatformPlugin([Runtime.nodeJS], () => NodePlatform());
  registerPlatformPlugin([
    Runtime.chrome,
    Runtime.phantomJS,
    Runtime.firefox,
    Runtime.safari,
    Runtime.internetExplorer
  ], () => BrowserPlatform.start());

  await executable.main(args);
}
