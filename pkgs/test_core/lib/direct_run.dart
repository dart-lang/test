import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test_api/backend.dart'; //ignore: deprecated_member_use
import 'package:test_api/src/backend/declarer.dart'; //ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart'; // ignore: implementation_imports
import 'package:test_api/src/frontend/utils.dart'; // ignore: implementation_imports
import 'package:test_api/src/utils.dart'; // ignore: implementation_imports

import 'src/runner/configuration.dart';
import 'src/runner/engine.dart';
import 'src/runner/plugin/environment.dart';
import 'src/runner/reporter.dart';
import 'src/runner/reporter/expanded.dart';
import 'src/runner/runner_suite.dart';
import 'src/runner/suite.dart';
import 'src/util/print_sink.dart';

Future<bool> directRunTests(FutureOr<void> Function() testMain,
    {Reporter Function(Engine)? reporter}) async {
  reporter ??= (engine) => ExpandedReporter.watch(engine, PrintSink(),
      color: Configuration.empty.color);
  final declarer = Declarer();
  await declarer.declare(testMain);

  await pumpEventQueue();

  final suite = RunnerSuite(const PluginEnvironment(), SuiteConfiguration.empty,
      declarer.build(), SuitePlatform(Runtime.vm, os: currentOSGuess),
      path: p.prettyUri(Uri.base));

  final engine = Engine()
    ..suiteSink.add(suite)
    ..suiteSink.close();

  reporter(engine);

  final success = await runZoned(() => Invoker.guard(engine.run),
      zoneValues: {#test.declarer: declarer});
  return success!;
}
