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

Future<Uri> _findObservatoryUrl(StreamQueue<List<int>> stdout) async {
  final newline = '\n'.codeUnitAt(0);
  final line = <List<int>>[];
  while (line.isEmpty || line.last.last != newline) {
    line.add(await stdout.next);
  }
  return Uri.parse(utf8.decode(line.expand((l) => l).toList()).split(' ').last);
}

Future<void> _showInfo(Uri serviceProtocolUrl) async {
  final service = await vmServiceConnectUri(
      convertToWebSocketUrl(serviceProtocolUrl: serviceProtocolUrl).toString());
  final vm = await service.getVM();
  final isolates = vm.isolates;
  print(isolates);

  for (final isolate in isolates) {
    final classList = await service.getClassList(isolate.id);
    for (final c in classList.classes) {
      if (c?.name?.endsWith('Subscription') ?? false) {
        final instances =
            (await service.getInstances(isolate.id, c.id, 100)).instances;
        if (instances.isEmpty) continue;
        print('${c.name}: ${instances.length} instances');
        for (final instance in instances) {
          final retainingPath =
              await service.getRetainingPath(isolate.id, instance.id, 100);
          print('Retained type: ${retainingPath.gcRootType}');
          for (final o in retainingPath.elements) {
            final value = o.value;
            if (value is InstanceRef) {
              print('-> ${value.classRef.name} in ${o.parentField}');
            } else {
              print('-> in ${o.parentField}');
            }
          }
        }
      }
    }
  }

  service.dispose();
}
