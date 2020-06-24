import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main(List<String> args) async {
  final process = await Process.start('dart', [
    '--enable-vm-service',
    'bin/test.dart',
    '--fake-long-exit',
    'test/runner/hybrid_test.dart',
    '--total-shards',
    '5',
    '--shard-index',
    '3',
    '-r',
    'expanded'
  ]);
  final testOut = StreamQueue(process.stdout);
  final observatoryUrl = await _findObservatoryUrl(testOut);
  print('Observatory Url: $observatoryUrl');
  unawaited(process.stderr.pipe(stderr));
  unawaited(testOut.rest.pipe(stdout));
  exitCode = 0;
  unawaited(process.exitCode.whenComplete(() {
    exit(exitCode);
  }));
  await Future.delayed(const Duration(minutes: 2));
  await _showInfo(observatoryUrl);
  exitCode = 1;
  process.kill();
}

Future<Uri> _findObservatoryUrl(StreamQueue<List<int>> testOut) async {
  final newline = '\n'.codeUnitAt(0);
  while (true) {
    final line = <List<int>>[];
    while (line.isEmpty || line.last.last != newline) {
      line.add(await testOut.next);
    }
    final decoded = utf8
        .decode([for (var part in line) ...part])
        .split('\n')
        .firstWhere((l) => l.isNotEmpty);
    if (decoded.startsWith('Observatory listening on')) {
      return Uri.parse(decoded.split(' ').last);
    } else {
      line.forEach(stdout.add);
    }
  }
}

Future<void> _showInfo(Uri serviceProtocolUrl) async {
  final skips = StreamController.broadcast();
  var skipCount = 0;
  final service = await runZonedGuarded(
      () => vmServiceConnectUri(
          convertToWebSocketUrl(serviceProtocolUrl: serviceProtocolUrl)
              .toString()), (error, st) {
    skipCount++;
    skips.add(null);
  });
  final vm = await service.getVM();
  final isolates = vm.isolates;
  print(isolates);

  for (final isolateRef in isolates) {
    final classList = await service.getClassList(isolateRef.id);
    final isolate = await service.getIsolate(isolateRef.id);
    final rootRefs = <InstanceRef>[];
    for (final c in classList.classes) {
      if (c?.name?.endsWith('Subscription') ?? false) {
        final instances =
            (await service.getInstances(isolateRef.id, c.id, 100)).instances;
        if (instances.isEmpty) continue;
        print('${c.name}: ${instances.length} instances');
        for (final instance in instances) {
          final retainingPath =
              await service.getRetainingPath(isolateRef.id, instance.id, 100);
          print('Retained type: ${retainingPath.gcRootType}');
          InstanceRef lastRetained;
          for (final o in retainingPath.elements) {
            final value = o.value;
            if (value is InstanceRef) {
              lastRetained = value;
              print(
                  '-> ${value.classRef.name} in ${o.parentField} {map: ${o.parentMapKey}, list: ${o.parentListIndex}}');
            } else if (value is ContextRef) {
              print('-> Context ${value.id}');
            } else {
              print(
                  '-> Non-Instance: ${value.runtimeType} in ${o.parentField} {map: ${o.parentMapKey}, list: ${o.parentListIndex}}');
            }
          }
          if (lastRetained != null) {
            rootRefs.add(lastRetained);
          }
        }
      }
    }
    print('Roots: ');
    for (final libraryRef in isolate.libraries) {
      final library =
          await service.getObject(isolateRef.id, libraryRef.id) as Library;
      if (library.name.startsWith('dart.') ||
          library.name.startsWith('builtin')) {
        continue;
      }
      for (final variableRef in library.variables) {
        try {
          final variableOrSkip = await Future.any([
            service.getObject(isolateRef.id, variableRef.id),
            skips.stream.first
          ]);
          if (variableOrSkip == null) continue;
          final variable = variableOrSkip as Field;
          for (final root in rootRefs.toList()) {
            if (root.classRef.id == variable.staticValue.classRef.id) {
              print(
                  'Potential Root: ${root.classRef.name} at ${variableRef.name} in library "${library.name}" at ${variable.location.script.uri}');
            }
          }
        } catch (_) {
          skipCount++;
        }
      }
    }
  }
  print('Errors reading $skipCount variables');

  service.dispose();
}
